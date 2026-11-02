const $ = (s, root=document) => root.querySelector(s);
const $$ = (s, root=document) => [...root.querySelectorAll(s)];
const state = {view:"dashboard", data:[], dashboard:null};
const titles = {dashboard:"Dashboard",patients:"Patients",doctors:"Doctors",appointments:"Appointments",admissions:"Admissions & Beds",pharmacy:"Pharmacy",laboratory:"Laboratory",billing:"Billing",reports:"Reports",about:"PL/SQL Map"};
const esc = value => String(value ?? "").replace(/[&<>"']/g, ch => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[ch]));
const money = n => new Intl.NumberFormat("en-IN",{style:"currency",currency:"INR",maximumFractionDigits:2}).format(Number(n||0));
function toast(message, error=false){const el=document.createElement("div");el.className="toast"+(error?" error":"");el.textContent=message;$("#toast-root").append(el);setTimeout(()=>el.remove(),4200);}
async function api(path, options={}) {
  const response=await fetch("/api/"+path,{headers:{"Content-Type":"application/json"},...options});
  const result=await response.json();
  if(!response.ok || !result.success) throw new Error(result.message||"Request failed.");
  return result.data;
}
function setView(view){state.view=view;$("#page-title").textContent=titles[view]||view;$("#crumb").textContent=view.toUpperCase();$$(".nav-item").forEach(b=>b.classList.toggle("active",b.dataset.view===view));renderView();}
$$(".nav-item").forEach(b=>b.addEventListener("click",()=>setView(b.dataset.view)));
$("#refresh-btn").addEventListener("click",renderView);
function stat(label,value,icon,foot="Current database records"){return `<article class="stat-card"><div class="stat-head">${esc(label)}<span class="stat-icon">${icon}</span></div><div class="stat-value">${esc(value)}</div><div class="stat-foot">${esc(foot)}</div></article>`;}
function tableHTML(rows){
 if(!rows.length)return `<div class="empty"><strong>No records found</strong>There are no records to display for this section.</div>`;
 const keys=Object.keys(rows[0]);
 return `<div class="table-wrap"><table><thead><tr>${keys.map(k=>`<th>${esc(k.replaceAll("_"," "))}</th>`).join("")}</tr></thead><tbody>${rows.map(row=>`<tr>${keys.map(k=>`<td>${cell(k,row[k])}</td>`).join("")}</tr>`).join("")}</tbody></table></div>`;
}
function cell(key,value){
 if(value===null||value===undefined)return '<span class="muted">—</span>';
 if(key==="status"||key==="abnormal_flag"){let v=String(value);let cls=/PAID|FREE|ACTIVE|COMPLETED|RESULT_READY|N$/.test(v)?"good":/PARTIAL|BOOKED|ORDERED|OCCUPIED|Y/.test(v)?"warn":/UNPAID|CANCELLED|EXPIRED/.test(v)?"bad":"";return `<span class="badge ${cls}">${esc(v)}</span>`;}
 if(typeof value==="number" && /amount|price|fee|revenue|balance|total|paid/.test(key))return esc(money(value));
 if(value instanceof Object)return esc(JSON.stringify(value));
 return esc(value);
}
async function renderView(){
 const root=$("#content");root.innerHTML='<div class="loading">Loading records…</div>';
 try{
  if(state.view==="dashboard"){state.dashboard=await api("dashboard");root.innerHTML=dashboardHTML(state.dashboard);}
  else if(state.view==="about"){root.innerHTML=aboutHTML();}
  else if(state.view==="reports"){const data=await api("reports");root.innerHTML=reportsHTML(data);}
  else {state.data=await api(state.view);root.innerHTML=moduleHTML(state.view,state.data);}
  bindContent();
 }catch(e){root.innerHTML=`<div class="panel"><div class="empty"><strong>Could not load ${esc(titles[state.view])}</strong>${esc(e.message)}<p><button class="secondary" id="retry">Try again</button></p></div></div>`;$("#retry")?.addEventListener("click",renderView);}
}
function dashboardHTML(d){
 const s=d.stats||{};
 return `<div class="welcome"><div><h2>Good to see you, ${esc(document.body.dataset.user||"team")} 👋</h2><p>Here is what's happening at your hospital today.</p></div><button class="primary" data-action="new-patient">＋ Register patient</button></div>
 <div class="stats-grid">${stat("Total patients",s.patients??"—","♙")}${stat("Active doctors",s.doctors??"—","✚")}${stat("Today's appointments",s.appointments??"—","▣")}${stat("Currently admitted",s.admitted??"—","▤")}${stat("Beds available",s.free_beds??"—","⌂")}${stat("Outstanding dues",money(s.outstanding),"₹")}</div>
 <div class="dashboard-grid"><section class="panel"><div class="panel-head"><h3>Recently registered patients</h3><button class="secondary" data-view="patients">View all</button></div>${tableHTML(d.recent_patients||[])}</section>
 <section class="panel"><div class="panel-head"><h3>Quick actions</h3></div><div class="panel-body"><div class="quick-grid"><button class="quick" data-action="new-patient"><span>♙</span><strong>New patient</strong><small>Register a patient</small></button><button class="quick" data-view="appointments"><span>▣</span><strong>Appointments</strong><small>View schedule</small></button><button class="quick" data-view="billing"><span>₹</span><strong>Billing</strong><small>Review invoices</small></button><button class="quick" data-view="pharmacy"><span>⚕</span><strong>Pharmacy</strong><small>Check medicine stock</small></button></div></div></section></div>`;
}
function moduleHTML(view,rows){
 const canAdd=view==="patients"||view==="appointments";
 return `<div class="welcome"><div><h2>${esc(titles[view])}</h2><p>Search and review records from the Oracle database.</p></div>${canAdd?`<button class="primary" data-action="${view==="patients"?"new-patient":"new-appointment"}">＋ ${view==="patients"?"Register patient":"Book appointment"}</button>`:""}</div><section class="panel"><div class="panel-head"><h3>${esc(titles[view])} records</h3><span class="badge">${rows.length} records</span></div><div class="panel-body"><div class="table-tools"><input class="search" id="table-search" placeholder="Search records…" aria-label="Search records"><button class="secondary" data-action="export">Export CSV</button></div><div id="data-table">${tableHTML(rows)}</div></div></section>`;
}
function reportsHTML(data){return `<div class="welcome"><div><h2>Reports & analytics</h2><p>Live summaries calculated from the Oracle database.</p></div><button class="secondary" data-action="export">Export low-stock CSV</button></div><div class="dashboard-grid"><section class="panel"><div class="panel-head"><h3>Medicines at or below reorder level</h3></div>${tableHTML(data.low_stock||[])}</section><section class="panel"><div class="panel-head"><h3>Revenue · last 7 days</h3></div><div class="panel-body"><div class="report-list">${(data.daily_revenue||[]).map(r=>`<div class="report-row"><span>${esc(r.day)}</span><strong>${esc(money(r.revenue))}</strong></div>`).join("")||'<p class="muted">No payment data for this period.</p>'}</div></div></section></div>`;}
function aboutHTML(){const items=[["Stored procedures","PATIENT_PKG.REGISTER_PATIENT","Encapsulates patient registration and validates input in the database."],["Functions","BILLING_PKG.CALCULATE_TOTAL","Calculates bill totals, discount, tax and balance."],["Triggers","TRG_PATIENT_AUDIT","Records important changes for accountability."],["Explicit cursors","REPORT_PKG.LOW_STOCK_REPORT","Fetches stock records for operational reports."],["Exception handling","Package business errors","Returns understandable errors for invalid business operations."],["Sequences","PATIENT_SEQ","Generates unique database identifiers."],["Views","V_PATIENT_SUMMARY","Simplifies reporting by combining related records."],["Transactions","Appointment and billing routines","Keeps related database changes consistent."]];return `<div class="welcome"><div><h2>PL/SQL concept map</h2><p>How this project demonstrates database programming concepts.</p></div></div><div class="about-grid">${items.map(x=>`<article class="concept"><h3>${esc(x[0])}</h3><p><code>${esc(x[1])}</code></p><p style="margin-top:8px">${esc(x[2])}</p></article>`).join("")}</div><p class="muted">See docs/PLSQL_CONCEPTS.md for the project report mapping and SQL files for implementation.</p>`;}
function bindContent(){
 $$("[data-view]").forEach(b=>b.addEventListener("click",()=>setView(b.dataset.view)));
 $$("[data-action]").forEach(b=>b.addEventListener("click",()=>action(b.dataset.action)));
 $("#table-search")?.addEventListener("input",e=>{const q=e.target.value.toLowerCase();const filtered=state.data.filter(r=>Object.values(r).some(v=>String(v??"").toLowerCase().includes(q)));$("#data-table").innerHTML=tableHTML(filtered);});
}
function action(name){if(name==="new-patient")showPatientModal();else if(name==="new-appointment")showAppointmentModal();else if(name==="export")exportCSV(state.data||[]);}
function showModal(title,body,onSubmit){
 const root=$("#modal-root");root.innerHTML=`<div class="modal-backdrop"><section class="modal" role="dialog" aria-modal="true"><div class="modal-head"><h3>${esc(title)}</h3><button class="icon-button" id="close-modal" aria-label="Close">×</button></div><form id="modal-form"><div class="modal-body">${body}</div><div class="modal-foot"><button type="button" class="secondary" id="cancel-modal">Cancel</button><button class="primary" type="submit">Save record</button></div></form></section></div>`;
 const close=()=>root.innerHTML="";$("#close-modal").onclick=close;$("#cancel-modal").onclick=close;$(".modal-backdrop").addEventListener("click",e=>{if(e.target.classList.contains("modal-backdrop"))close();});$("#modal-form").addEventListener("submit",async e=>{e.preventDefault();const btn=$('button[type="submit"]',e.currentTarget);btn.disabled=true;btn.textContent="Saving…";try{await onSubmit(new FormData(e.currentTarget));close();toast("Saved successfully.");renderView();}catch(err){toast(err.message,true);btn.disabled=false;btn.textContent="Save record";}});
}
function field(label,name,type="text",required=false,extra=""){return `<div class="field"><label for="${esc(name)}">${esc(label)}${required?" *":""}</label><input id="${esc(name)}" name="${esc(name)}" type="${esc(type)}" ${required?"required":""} ${extra}></div>`;}
function showPatientModal(){showModal("Register a patient",`<div class="form-grid">${field("Full name","full_name","text",true,'maxlength="100"')}${field("Phone (10 digits)","phone","tel",true,'pattern="[0-9]{10}" maxlength="10"')}${field("Date of birth","dob","date")}${`<div class="field"><label for="gender">Gender</label><select name="gender" id="gender"><option>Other</option><option>Female</option><option>Male</option></select></div>`}${`<div class="field"><label for="blood_group">Blood group</label><select name="blood_group" id="blood_group"><option value="">Not provided</option>${["A+","A-","B+","B-","AB+","AB-","O+","O-"].map(v=>`<option>${v}</option>`).join("")}</select></div>`}${field("Emergency contact","emergency_contact","tel",false,'pattern="[0-9]{10}"')}${`<div class="field wide"><label for="allergies">Allergies / notes</label><textarea id="allergies" name="allergies"></textarea></div>`}</div>`,async form=>{const payload=Object.fromEntries(form.entries());await api("patients",{method:"POST",body:JSON.stringify(payload)});});}
function showAppointmentModal(){showModal("Book an appointment",`<div class="form-grid">${field("Patient ID","patient_id","number",true,'min="1"')}${field("Doctor ID","doctor_id","number",true,'min="1"')}${field("Appointment date and time","appointment_date","datetime-local",true)}${`<div class="field wide"><label for="reason">Reason</label><textarea name="reason" id="reason">Consultation</textarea></div>`}</div><p class="muted">Use the numeric patient and doctor IDs shown in the database. The PL/SQL package checks booking rules.</p>`,async form=>{const p=Object.fromEntries(form.entries());await api("appointments",{method:"POST",body:JSON.stringify(p)});});}
function exportCSV(rows){if(!rows.length){toast("There are no rows to export.",true);return;}const keys=Object.keys(rows[0]);const csv=[keys.join(","),...rows.map(r=>keys.map(k=>`"${String(r[k]??"").replaceAll('"','""')}"`).join(","))].join("\r\n");const url=URL.createObjectURL(new Blob([csv],{type:"text/csv;charset=utf-8;"}));const a=document.createElement("a");a.href=url;a.download=`medicare-${state.view}.csv`;a.click();URL.revokeObjectURL(url);}
renderView();
