-- Voting and administration RPCs
-- IMPORTANT: replace ADMIN_EMAIL below when deploying another instance.

create or replace function public.is_election_admin()
returns boolean language sql stable security definer set search_path=public as $$
 select lower(coalesce(auth.jwt()->>'email','')) = lower('sabi.bandiri@ufrpe.br')
$$;

create or replace function public.verify_voter(p_code text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v public.eligible_voters%rowtype;
begin
 select * into v from public.eligible_voters where voter_code_hash=encode(digest(trim(p_code),'sha256'),'hex');
 if not found then return jsonb_build_object('valid',false,'reason','invalid'); end if;
 if v.has_voted then return jsonb_build_object('valid',false,'reason','already_voted'); end if;
 if (select status from public.election_config where id=1)<>'open' then return jsonb_build_object('valid',false,'reason','closed'); end if;
 return jsonb_build_object('valid',true,'display_name',v.display_name);
end $$;

create or replace function public.cast_vote(p_code text,p_choices jsonb)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v public.eligible_voters%rowtype; b uuid:=gen_random_uuid(); receipt text:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,12));
x jsonb; pos public.positions%rowtype; cand public.candidates%rowtype; ctype text; cid bigint; mid uuid; cnt int:=0;
begin
 if (select status from public.election_config where id=1)<>'open' then raise exception 'ELECTION_CLOSED'; end if;
 select * into v from public.eligible_voters where voter_code_hash=encode(digest(trim(p_code),'sha256'),'hex') for update;
 if not found then raise exception 'INVALID_VOTER'; end if;
 if v.has_voted then raise exception 'ALREADY_VOTED'; end if;
 if jsonb_typeof(p_choices)<>'array' then raise exception 'INVALID_BALLOT'; end if;
 for x in select * from jsonb_array_elements(p_choices) loop
  select * into pos from public.positions where id=(x->>'position_id')::bigint;
  if not found then raise exception 'INVALID_POSITION'; end if;
  ctype:=x->>'choice_type'; cid:=nullif(x->>'candidate_id','')::bigint; mid:=nullif(x->>'nominated_member_id','')::uuid;
  if pos.ballot_type='competitive' then
   if ctype not in ('candidate','blank') then raise exception 'INVALID_CHOICE'; end if;
   if ctype='candidate' then
    select * into cand from public.candidates where id=cid and position_id=pos.id and active and consent_status='confirmed';
    if not found then raise exception 'INVALID_CANDIDATE'; end if;
   else cid:=null; end if; mid:=null;
  elsif pos.ballot_type='confirmation' then
   if ctype not in ('confirm','not_confirm','blank') then raise exception 'INVALID_CHOICE'; end if;
   select * into cand from public.candidates where position_id=pos.id and active and consent_status='confirmed' order by id limit 1;
   if not found then raise exception 'NO_CANDIDATE'; end if; cid:=cand.id; mid:=null;
  elsif pos.ballot_type='indication' then
   if ctype not in ('self_candidate','nominate','no_nomination') then raise exception 'INVALID_CHOICE'; end if; cid:=null;
   if ctype='nominate' then
    if mid is null or not exists(select 1 from public.members where id=mid and active) then raise exception 'INVALID_NOMINEE'; end if;
   else mid:=null; end if;
  end if; cnt:=cnt+1;
 end loop;
 if cnt<>(select count(*) from public.positions) then raise exception 'INCOMPLETE_BALLOT'; end if;
 if (select count(distinct(z->>'position_id')) from jsonb_array_elements(p_choices) z)<>cnt then raise exception 'DUPLICATE_POSITION'; end if;
 insert into public.ballots(id,receipt_code) values(b,receipt);
 for x in select * from jsonb_array_elements(p_choices) loop
  insert into public.ballot_choices(ballot_id,position_id,candidate_id,choice_type,nominated_member_id)
  values(b,(x->>'position_id')::bigint,nullif(x->>'candidate_id','')::bigint,x->>'choice_type',nullif(x->>'nominated_member_id','')::uuid);
 end loop;
 update public.eligible_voters set has_voted=true,voted_at=now() where id=v.id;
 insert into public.participation_log(voter_id,receipt_hash) values(v.id,encode(digest(receipt,'sha256'),'hex'));
 return jsonb_build_object('receipt',receipt,'submitted_at',now());
end $$;

create or replace function public.admin_dashboard()
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare st text; total int; voted int; out jsonb;
begin
 if not public.is_election_admin() then raise exception 'UNAUTHORIZED'; end if;
 select status into st from election_config where id=1;
 select count(*),count(*) filter(where has_voted) into total,voted from eligible_voters where display_name not like 'ELEITOR DE TESTE%';
 out:=jsonb_build_object('status',st,'eligible',total,'voted',voted,'remaining',total-voted,'participation',case when total>0 then round(100.0*voted/total,1) else 0 end);
 if st='closed' then out:=out||jsonb_build_object('results',(select coalesce(jsonb_agg(x),'[]'::jsonb) from (
  select p.sort_order,p.name position,case when bc.choice_type='candidate' then c.name when bc.choice_type='confirm' then 'Confirmo' when bc.choice_type='not_confirm' then 'Não confirmo' when bc.choice_type='blank' then 'Voto em branco' when bc.choice_type='self_candidate' then 'Autocandidatura' when bc.choice_type='nominate' then 'Indicação: '||m.full_name else 'Sem indicação' end choice,count(*) votes
  from ballot_choices bc join ballots b on b.id=bc.ballot_id join positions p on p.id=bc.position_id left join candidates c on c.id=bc.candidate_id left join members m on m.id=bc.nominated_member_id
  group by p.sort_order,p.name,bc.choice_type,c.name,m.full_name order by p.sort_order,votes desc)x)); end if;
 return out;
end $$;

create or replace function public.admin_set_status(p_status text)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_election_admin() then raise exception 'UNAUTHORIZED'; end if;
 if p_status not in ('open','closed') then raise exception 'INVALID_STATUS'; end if;
 update election_config set status=p_status,opened_at=case when p_status='open' then now() else opened_at end,closed_at=case when p_status='closed' then now() else null end,updated_at=now() where id=1;
 return jsonb_build_object('status',p_status);
end $$;

revoke all on function public.verify_voter(text) from public;
revoke all on function public.cast_vote(text,jsonb) from public;
grant execute on function public.verify_voter(text) to anon,authenticated;
grant execute on function public.cast_vote(text,jsonb) to anon,authenticated;
revoke all on function public.is_election_admin() from public;
revoke all on function public.admin_dashboard() from public;
revoke all on function public.admin_set_status(text) from public;
grant execute on function public.is_election_admin() to authenticated;
grant execute on function public.admin_dashboard() to authenticated;
grant execute on function public.admin_set_status(text) to authenticated;
