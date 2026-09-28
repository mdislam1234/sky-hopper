-- Sky Hopper Phase 13A: one server-authoritative rewarded bonus per saved run.
create table public.rewarded_ad_claims (
  user_id uuid not null references auth.users(id) on delete cascade,
  run_id uuid not null,
  game_score_id bigint not null references public.game_scores(id) on delete cascade,
  bonus_coins integer not null check (bonus_coins between 1 and 25),
  claimed_at timestamptz not null default now(),
  primary key (user_id, run_id),
  unique (game_score_id),
  foreign key (user_id, run_id)
    references public.game_scores(user_id, run_id) on delete cascade
);

create index rewarded_ad_claims_user_claimed_idx
  on public.rewarded_ad_claims (user_id, claimed_at desc);

alter table public.rewarded_ad_claims enable row level security;

revoke all on public.rewarded_ad_claims from public, anon, authenticated;
grant select on public.rewarded_ad_claims to authenticated;

create policy rewarded_ad_claims_select_own on public.rewarded_ad_claims
  for select to authenticated using ((select auth.uid()) = user_id);

create function public.claim_rewarded_run_bonus(p_run_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_score public.game_scores%rowtype;
  v_claim public.rewarded_ad_claims%rowtype;
  v_bonus integer;
  v_inserted integer;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_run_id is null then
    raise exception 'Invalid run' using errcode = '22023';
  end if;

  select * into v_profile from public.profiles
    where id = v_user for update;
  if not found then
    raise exception 'Profile unavailable' using errcode = 'P0002';
  end if;

  select s.* into v_score
    from public.game_scores s
    join public.run_progression r
      on r.user_id = s.user_id and r.run_id = s.run_id
    where s.user_id = v_user and s.run_id = p_run_id
      and not r.is_daily;
  if not found or v_score.coins_collected <= 0 then
    raise exception 'Reward unavailable' using errcode = 'SH004';
  end if;

  -- The server derives the reward from the immutable saved run. The client
  -- never supplies a coin amount. The cap keeps the optional ad from
  -- overwhelming gameplay and progression rewards.
  v_bonus := least(25, greatest(1, (v_score.coins_collected + 1) / 2));

  insert into public.rewarded_ad_claims
    (user_id, run_id, game_score_id, bonus_coins)
  values (v_user, p_run_id, v_score.id, v_bonus)
  on conflict (user_id, run_id) do nothing
  returning * into v_claim;
  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    select * into v_claim from public.rewarded_ad_claims
      where user_id = v_user and run_id = p_run_id;
  else
    if v_profile.total_coins::bigint + v_bonus::bigint > 2147483647 then
      raise exception 'Coin balance limit reached' using errcode = '22003';
    end if;
    update public.profiles set total_coins = total_coins + v_bonus
      where id = v_user returning * into v_profile;
  end if;

  return jsonb_build_object(
    'run_id', v_claim.run_id,
    'bonus_coins', v_claim.bonus_coins,
    'new_total_coins', v_profile.total_coins,
    'already_claimed', v_inserted = 0,
    'profile_updated_at', v_profile.updated_at
  );
end;
$$;

revoke all on function public.claim_rewarded_run_bonus(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.claim_rewarded_run_bonus(uuid)
  to authenticated;
