-- Sky Hopper Phase 7: private best-score leaderboard and authoritative cosmetics.
create table public.skin_catalog (
  id text primary key check (id ~ '^[a-z][a-z0-9_]{0,39}$'),
  name text not null check (length(btrim(name)) > 0),
  description text,
  cost integer not null check (cost >= 0),
  primary_color text not null check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  secondary_color text not null check (secondary_color ~ '^#[0-9A-Fa-f]{6}$'),
  accent_color text check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.skin_catalog
  (id, name, description, cost, primary_color, secondary_color, accent_color, sort_order)
values
  ('default', 'Golden Hopper', 'The original little ray of sunshine.', 0, '#FFD45A', '#E9A834', '#123B69', 0),
  ('sunset', 'Sunset Glow', 'Warm coral skies for your next climb.', 10, '#FF8B70', '#C94C65', '#542344', 1),
  ('mint', 'Mint Breeze', 'A fresh splash of spring in the clouds.', 25, '#74E3B4', '#299C84', '#174C53', 2),
  ('cosmic', 'Cosmic Drift', 'Violet starlight, one bounce at a time.', 50, '#B29AFF', '#7552BD', '#35245C', 3),
  ('royal', 'Royal Blue', 'A bright blue crown above the clouds.', 100, '#72B8FF', '#326ABC', '#17365D', 4);

alter table public.skin_catalog enable row level security;
revoke all on public.skin_catalog from public, anon, authenticated;
grant select on public.skin_catalog to authenticated;
create policy skin_catalog_read_active on public.skin_catalog
  for select to authenticated using (is_active);

-- Selection must validate active catalog membership as well as ownership.
-- Preserve the original policies and owned-skin foreign key.
revoke update (selected_skin) on public.profiles from public, anon, authenticated;

create function public.unlock_skin(p_skin_id text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_skin public.skin_catalog%rowtype;
  v_profile public.profiles%rowtype;
  v_unlocked timestamptz;
  v_owned boolean;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  select * into v_skin from public.skin_catalog where id = p_skin_id and is_active;
  if not found then
    raise exception 'Skin unavailable' using errcode = '22023';
  end if;
  -- Same owner lock as submit_game_result: spending and earnings are atomic.
  select * into v_profile from public.profiles where id = v_user for update;
  if not found then
    raise exception 'Profile unavailable' using errcode = 'P0002';
  end if;
  select unlocked_at into v_unlocked from public.user_skins
    where user_id = v_user and skin_id = p_skin_id;
  v_owned := found;
  if not v_owned then
    if v_profile.total_coins < v_skin.cost then
      raise exception 'Not enough coins' using errcode = 'SH001';
    end if;
    update public.profiles set total_coins = total_coins - v_skin.cost
      where id = v_user returning * into v_profile;
    insert into public.user_skins(user_id, skin_id)
      values (v_user, p_skin_id) returning unlocked_at into v_unlocked;
  end if;
  return jsonb_build_object(
    'skin_id', p_skin_id, 'already_owned', v_owned,
    'cost_charged', case when v_owned then 0 else v_skin.cost end,
    'new_total_coins', v_profile.total_coins, 'unlocked_at', v_unlocked,
    'profile_updated_at', v_profile.updated_at
  );
end;
$$;

create function public.select_skin(p_skin_id text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_profile public.profiles%rowtype;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  perform 1 from public.skin_catalog where id = p_skin_id and is_active;
  if not found then
    raise exception 'Skin unavailable' using errcode = '22023';
  end if;
  select * into v_profile from public.profiles where id = v_user for update;
  if not found then
    raise exception 'Profile unavailable' using errcode = 'P0002';
  end if;
  perform 1 from public.user_skins where user_id = v_user and skin_id = p_skin_id;
  if not found then
    raise exception 'Skin not owned' using errcode = 'SH002';
  end if;
  update public.profiles set selected_skin = p_skin_id where id = v_user
    returning * into v_profile;
  return jsonb_build_object('selected_skin', v_profile.selected_skin,
    'profile_updated_at', v_profile.updated_at);
end;
$$;

create function public.get_leaderboard(p_limit integer default 50)
returns table (
  rank bigint, display_name text, avatar_url text,
  best_score integer, best_height integer, played_at timestamptz,
  is_current_user boolean
)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'Limit must be between 1 and 100' using errcode = '22023';
  end if;
  return query
    with personal_best as (
      select s.user_id, s.score, s.height, s.played_at, s.id,
        row_number() over (
          partition by s.user_id order by s.score desc, s.height desc, s.played_at, s.id
        ) as personal_rank
      from public.game_scores s
    )
    select row_number() over (order by b.score desc, b.height desc, b.played_at, b.id),
      coalesce(nullif(btrim(p.display_name), ''), 'Player'),
      case when p.avatar_url ~ '^https://' then p.avatar_url else null end,
      b.score, b.height, b.played_at, b.user_id = v_user
    from personal_best b join public.profiles p on p.id = b.user_id
    where b.personal_rank = 1
    order by b.score desc, b.height desc, b.played_at, b.id
    limit p_limit;
end;
$$;

revoke all on function public.unlock_skin(text), public.select_skin(text),
  public.get_leaderboard(integer) from public, anon, authenticated, service_role;
grant execute on function public.unlock_skin(text), public.select_skin(text),
  public.get_leaderboard(integer) to authenticated;
