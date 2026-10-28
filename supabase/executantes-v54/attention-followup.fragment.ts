  // Integrar após selected/scoped/profile autorizados e antes das ações attention51.
  if(['attention-dashboard-list','attention-followup-detail','attention-followup-save'].includes(b.action)){
   if(!uuid(b.companyId))fail('Selecione a empresa da avaliação.');
   const attentionResult=async(name:string,params:any)=>{
    const result=await scoped.rpc(name,params);
    if(result.error){const code=String(result.error.code||'');
     if(code==='42501')throw new RequestError('Acesso não autorizado ou revogado.',403);
     if(code==='P5404')throw new RequestError('Avaliação não encontrada no seu acesso.',404);
     if(code==='P5409')throw new RequestError('Outro gestor atualizou o acompanhamento. Reabra a avaliação antes de salvar.',409);
     if(code.startsWith('22')||code.startsWith('23'))fail('Confira filtros, situação e descrição do acompanhamento.');
     throw new RequestError('Não foi possível confirmar o acompanhamento. Atualize a consulta antes de tentar novamente.',503);
    }return result.data;
   };
   if(b.action==='attention-dashboard-list'){
    const date54=(value:any)=>{if(value===undefined||value==='')return null;if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))fail('Data inválida.');const d=new Date(value+'T12:00:00Z');if(!Number.isFinite(+d)||d.toISOString().slice(0,10)!==value)fail('Data inválida.');return value;};
    const from=date54(b.dateFrom),to=date54(b.dateTo);
    if(from&&to&&from>to)fail('O início do período deve ser anterior ao fim.');
    if(b.employeeId!==undefined&&b.employeeId!==''&&!uuid(b.employeeId))fail('Colaborador inválido.');
    if(b.employeeNumber!==undefined&&(typeof b.employeeNumber!=='string'||b.employeeNumber.length>160))fail('Matrícula inválida.');
    const offset=b.offset===undefined?0:b.offset,limit=b.limit===undefined?50:b.limit;
    if(!Number.isInteger(offset)||offset<0||offset>1000000||!Number.isInteger(limit)||limit<1||limit>100)fail('Página inválida.');
    const data=await attentionResult('ppl_attention_dashboard_v54',{p_company:selected.id,p_employee:b.employeeId||null,p_number:(b.employeeNumber||'').trim(),p_from:from,p_to:to,p_status:b.status||'',p_followup:b.followupStatus||'',p_offset:offset,p_limit:limit});
    return respond({...data,moduleVersion:54});
   }
   if(!uuid(b.id))fail('Avaliação inválida.');
   if(b.action==='attention-followup-detail')return respond({...await attentionResult('ppl_attention_followup_detail_v54',{p_company:selected.id,p_id:b.id}),moduleVersion:54});
   if(!['aberta','em_andamento','concluida'].includes(b.status)||typeof b.note!=='string'||!b.note.trim()||b.note.trim().length>4000||!Number.isInteger(b.expectedRevision)||b.expectedRevision<0)fail('Informe a situação e uma descrição de até 4.000 caracteres.');
   return respond({...await attentionResult('ppl_attention_followup_save_v54',{p_company:selected.id,p_id:b.id,p_status:b.status,p_note:b.note,p_expected:b.expectedRevision}),moduleVersion:54});
  }
