-- Non-sensitive election seed data. No eligible voter credentials are included.
insert into public.election_config(id,title,chapter_name,term,faculty_advisor,status)
values(1,'ELEIÇÃO DA PRIMEIRA DIRETORIA','UABJ OPTICA STUDENT CHAPTER','2026–2027','Prof. Dr. Sabi Yari Moïse Bandiri','closed')
on conflict(id) do nothing;

insert into public.positions(code,name,ballot_type,sort_order) values
('president','Presidente','competitive',1),
('vice_president','Vice-Presidente','competitive',2),
('secretary','Secretário','confirmation',3),
('treasurer','Tesoureiro','confirmation',4),
('communication','Responsável de Comunicação e Marketing','indication',5),
('events','Coordenador de Eventos e Divulgação Científica','indication',6)
on conflict(code) do nothing;

insert into public.candidates(position_id,name,consent_status,active)
select p.id,v.name,'confirmed',true from (values
('president','Guilherme Leite'),('president','Lawrence Lopes'),('president','Mariana Martins'),
('vice_president','Lucas Almeida'),('vice_president','Vinicius Pereira'),
('secretary','José Guilherme'),('treasurer','Mariana Martins')
) v(code,name) join public.positions p on p.code=v.code
where not exists(select 1 from public.candidates c where c.position_id=p.id and c.name=v.name);

insert into public.members(full_name) select v.name from (values
('Lawrence Lopes Gomes Silva'),('Guilherme Leite Cavalcanti'),('Vinicius Pereira de Lira'),
('Mariana Martins Albuquerque Vasconcelos'),('Lucas de Almeida Barreto'),('José Guilherme')
) v(name) where not exists(select 1 from public.members m where m.full_name=v.name);
