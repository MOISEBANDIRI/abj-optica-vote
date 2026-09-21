const SUPABASE_URL='https://asmmfohbfyngblylrtlg.supabase.co';
const SUPABASE_KEY='sb_publishable_6yEmva0YUFiwo0WPt78QpQ_3pjNNoV-';
const headers={apikey:SUPABASE_KEY,Authorization:'Bearer '+SUPABASE_KEY};
async function api(path){const r=await fetch(SUPABASE_URL+'/rest/v1/'+path,{headers});if(!r.ok)throw new Error(await r.text());return r.json()}
function esc(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
async function load(){
 try{
  const [cfg,positions,candidates]=await Promise.all([
   api('election_config?select=*&id=eq.1'),
   api('positions?select=*&order=sort_order.asc'),
   api('candidates?select=*&active=eq.true')
  ]);
  const c=cfg[0]||{status:'closed'};
  const badge=document.getElementById('statusBadge'), title=document.getElementById('stateTitle'), text=document.getElementById('stateText');
  badge.className='status '+c.status;
  if(c.status==='open'){badge.textContent='ELEIÇÃO ABERTA';title.textContent='Votação aberta';text.textContent='Eleitores elegíveis podem iniciar a votação.';document.querySelector('.state-icon').style.color='#10b981'}
  else{badge.textContent='ELEIÇÃO FECHADA';title.textContent='A votação ainda não está aberta';text.textContent='A cédula pode ser visualizada abaixo. O acesso à votação será liberado pela organização do processo eleitoral.'}
  const byPos={};candidates.forEach(x=>(byPos[x.position_id]??=[]).push(x));
  document.getElementById('positions').innerHTML=positions.map(p=>{
   const list=byPos[p.id]||[];
   let body='';
   if(p.ballot_type==='indication') body='<p class="empty">Sem candidatura registrada. O processo prevê autocandidatura ou indicação de integrante durante a votação.</p>';
   else body=list.map(x=>'<div class="candidate"><span>'+esc(x.name)+'</span>'+(x.consent_status==='pending'?'<span class="pending">ANUÊNCIA PENDENTE</span>':'')+'</div>').join('');
   return '<article class="position"><h4>'+esc(p.name)+'</h4>'+body+'</article>'
  }).join('');
 }catch(e){
  document.getElementById('statusBadge').textContent='INDISPONÍVEL';
  document.getElementById('stateTitle').textContent='Não foi possível consultar a eleição';
  document.getElementById('stateText').textContent='Tente novamente em alguns instantes.';
  document.getElementById('positions').innerHTML='<article class="position"><p class="empty">Falha temporária ao carregar os dados.</p></article>';
  console.error(e)
 }
}
load();