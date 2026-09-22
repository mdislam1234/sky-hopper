-- Sky Hopper Phase 6: atomic, owner-bound, retry-safe completed runs.
-- Nullable run_id preserves any historical Phase 3 rows without inventing IDs.
alter table public.game_scores add column run_id uuid;
alter table public.game_scores add constraint game_scores_user_run_key unique (user_id, run_id);

-- All new client writes go through the RPC. Keep the five Phase 3 RLS policies.
revoke insert on public.game_scores from public, anon, authenticated;
revoke insert (user_id, score, height, coins_collected) on public.game_scores from public, anon, authenticated;
revoke usage on sequence public.game_scores_id_seq from public, anon, authenticated;

create function public.submit_game_result(
  p_run_id uuid,
  p_score integer,
  p_height integer,
  p_coins_collected integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_score public.game_scores%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if p_run_id is null or p_score is null or p_height is null
      or p_coins_collected is null or p_score < 0 or p_height < 0
      or p_coins_collected < 0 then
    raise exception 'Invalid game result' using errcode = '22023';
  end if;

  -- Serialize submissions per owner, including concurrent retries of one UUID.
  select p.* into v_profile from public.profiles p
    where p.id = v_user_id for update;
  if not found then
    raise exception 'Profile unavailable' using errcode = 'P0002';
  end if;

  select s.* into v_score from public.game_scores s
    where s.user_id = v_user_id and s.run_id = p_run_id;
  if found then
    if v_score.score <> p_score or v_score.height <> p_height
        or v_score.coins_collected <> p_coins_collected then
      raise exception 'Run ID already used for another result' using errcode = '22023';
    end if;
    -- A lost response can be retried without granting the coins again.
  else
    if v_profile.total_coins::bigint + p_coins_collected::bigint > 2147483647 then
      raise exception 'Coin balance limit reached' using errcode = '22003';
    end if;
    insert into public.game_scores (user_id, run_id, score, height, coins_collected)
      values (v_user_id, p_run_id, p_score, p_height, p_coins_collected)
      returning * into v_score;
    update public.profiles p
      set total_coins = p.total_coins + p_coins_collected
      where p.id = v_user_id returning p.* into v_profile;
  end if;

  return jsonb_build_object(
    'run_id', v_score.run_id,
    'game_score_id', v_score.id,
    'saved_score', v_score.score,
    'saved_height', v_score.height,
    'coins_collected', v_score.coins_collected,
    'new_total_coins', v_profile.total_coins,
    'profile_updated_at', v_profile.updated_at,
    'played_at', v_score.played_at
  );
end;
$$;

revoke all on function public.submit_game_result(uuid, integer, integer, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.submit_game_result(uuid, integer, integer, integer)
  to authenticated;
