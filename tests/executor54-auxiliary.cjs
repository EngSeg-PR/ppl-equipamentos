/* Regression: an auxiliary Vale inspector is not the authenticated author. */
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const field={name:'v_scaffoldInspector',type:'staff',relatedEmployee:'v_scaffoldEmployee',label:'Inspetor adicional'};
const input={value:'MATRICULA-HISTORICA'},select={value:'historical',dataset:{procedureStaff:field.name}};
const context={window:{PRContext:{employees:[{id:'author',name:'Autor autenticado',employee_number:'QA-A'}]},PRExecutor:{required:()=>true,people:()=>[{id:'author',name:'Autor autenticado'},{id:'other',name:'Outro inspetor'}]}},current:{model:{reportLayout:{type:'procedure-table'},identifiers:[field]},staff:{id:'author'},fields:{v_scaffoldInspector_id:'historical',v_scaffoldInspector:'Responsável histórico',v_scaffoldEmployee:'MATRICULA-HISTORICA'}},document:{querySelector:()=>input,querySelectorAll:()=>[select]},esc:x=>String(x??''),nativeChecklist:r=>r.model.reportLayout.type==='excel-original'};
context.PRContext=context.window.PRContext;
vm.createContext(context);vm.runInContext(fs.readFileSync(path.resolve(__dirname,'../procedure-form.js'),'utf8'),context);
vm.runInContext(fs.readFileSync(path.resolve(__dirname,'../native-checklist.js'),'utf8'),context);
const before=JSON.stringify(context.current.fields);
assert(context.procedureIdentifier(field).includes('value="historical" selected'));
context.captureProcedureStaff();assert.equal(JSON.stringify(context.current.fields),before,'Preserve historical auxiliary on first capture');
context.current.model.reportLayout.type='excel-original';context.captureNativeStaff();assert.equal(JSON.stringify(context.current.fields),before,'Preserve historical auxiliary on native form');
select.value='other';context.captureNativeStaff();assert.equal(input.value,'');assert.equal(context.current.fields.v_scaffoldInspector,'Outro inspetor');
input.value='QA-B';context.captureNativeStaff();assert.equal(context.current.fields.v_scaffoldEmployee,'QA-B');assert.equal(context.current.staff.id,'author');
select.value='author';context.captureNativeStaff();assert.equal(input.value,'QA-A');assert.equal(context.current.fields.v_scaffoldEmployee,'QA-A');
assert(!JSON.stringify(context.procedureStaffRows(field)).includes('QA-B'),'Public names directory has no other matrícula');
console.log('PASS auxiliary54: historical Vale identity preserved, additional role independent, new choice clears old matrícula, manual alternative and own autofill.');
