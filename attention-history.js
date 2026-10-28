/* Authenticated attention assessments. Measurements are never a release decision. */
window.PRAttentionHistory = (() => {
  const E = value => PR.escape(value);
  const text = value => value === null || value === undefined || value === '' ? '—' : String(value);
  const numeric = value => typeof value === 'number' && Number.isFinite(value);
  const number = value => numeric(value) ? value.toLocaleString('pt-BR', { maximumFractionDigits: 1 }) : '—';
  const time = value => numeric(value) && value >= 0 ? number(value / 1000) + ' s' : '—';
  const timestamp = value => {
    const date = new Date(value);
    return value && Number.isFinite(date.getTime())
      ? date.toLocaleString('pt-BR', { timeZone: 'America/Fortaleza' }) : '—';
  };
  const moment = value => ({ inicio: 'Início da jornada', durante: 'Durante a jornada' }[value] || 'Não informado');
  const state = value => value === 'completa' ? 'Completa' : 'Incompleta';
  const followupState = value => ({sem_acompanhamento:'Sem acompanhamento',aberta:'Aberto',em_andamento:'Em andamento',concluida:'Concluído'}[value] || 'Sem acompanhamento');

  const classification = metrics => {
    const c=metrics?.classification;
    if(!c)return '<p class="platform-note">Classificação indisponível para este protocolo.</p>';
    const label=c.level || (c.state==='base_em_formacao'?'Base em formação':c.state==='qualidade_insuficiente'?'Qualidade técnica insuficiente':'Referência insuficiente');
    const fields={mediana_reacao_ms:'Reação mediana',lentos10_media_ms:'Média dos 10% mais lentos',dp_reacao_ms:'Desvio dos tempos',lapsos:'Lapsos',omissoes:'Omissões',antecipacoes:'Antecipações',comissoes:'Comissões',declinio_ms:'Declínio entre quartos'};
    return `<section class="attention-classification"><h3>Classificação experimental: ${E(label)}</h3>${c.state==='nao_interpretavel'?'<p>Avaliação não interpretável. O rótulo refere-se à aplicação do teste e não presume intenção ou culpa.</p>':''}<p>${E(c.guidance)}</p><ul>${(c.reasons||[]).map(r=>`<li>${E(r)}</li>`).join('')}</ul><p class="platform-note">Pontos de corte sujeitos à validação pela equipe de saúde/estatística. Não é diagnóstico, liberação para trabalho ou probabilidade de acidente.</p><details><summary>Como foi calculado</summary><p>Regra ${E(c.ruleVersion)} · ${E(c.formulaVersion)}. z = (valor atual − média de referência) / desvio-padrão populacional da referência. Piora positiva; maior z entre parâmetros e referências.</p><p>Normal: z ≤ ${E(c.config?.z1)}; Limítrofe: até ${E(c.config?.z2)}; Alterado: até ${E(c.config?.z3)}; Significativamente Alterado: acima de ${E(c.config?.z3)}. Os percentuais de Gauss não são quotas.</p>${c.individualCount!==undefined?`<p>Base individual ${E(c.individualCount)} / ${E(c.config?.individualMinimum)}; populacional ${E(c.populationCount)} / ${E(c.config?.populationMinimum)}, ${E(c.populationPeople)} pessoas. Habituação: ${E(c.habituation)} testes elegíveis. O teste atual e a sequência numérica não entram nas referências.</p>`:''}<ul>${(c.scores||[]).map(s=>`<li>${E(s.reference)} · ${E(fields[s.parameter]||s.parameter)}: valor ${E(number(s.value))}, média ${E(number(s.mean))}, DP ${E(number(s.sd))}, z ${E(s.z===null?'não comparável':number(s.z))}.</li>`).join('')}</ul></details></section>`;
  };

  function create({ host, company, companies = [company], employees = [], canConfigure = false, isCurrent = () => true }) {
    if (!host || !company?.id) throw Error('Empresa ou área de consulta indisponível.');
    let alive = true, listToken = 0, detailToken = 0, rows = [], nextOffset = null, dialog = null, summary = null;
    const current = () => alive && isCurrent();
    const companyMap = new Map(companies.filter(item => item?.id).map(item => [item.id, item]));
    if (!companyMap.has(company.id)) companyMap.set(company.id, company);
    const people = new Map(employees.filter(item => item?.id).map(item => [
      (item.company_id || company.id) + ':' + item.id, { ...item, company_id: item.company_id || company.id },
    ]));
    const container = document.createElement('section');
    container.className = 'attention-history';
    const query = selector => container.querySelector(selector);
    const value = selector => query(selector)?.value || '';
    const status = (message, error = false) => {
      if (!current()) return;
      const node = query('[data-attention-status]');
      node.setAttribute('role', error ? 'alert' : 'status');
      node.textContent = message;
    };

    function closeDetail() {
      ++detailToken;
      if (!dialog) return;
      const previous = dialog;
      dialog = null;
      if (previous.open) previous.close();
      previous.remove();
    }

    function personOptions(selected = '') {
      const cid = value('[name=companyId]');
      const list = [...people.values()].filter(person => person.company_id === cid)
        .sort((a, b) => String(a.name).localeCompare(String(b.name), 'pt-BR'));
      if (selected && !list.some(person => person.id === selected)) {
        list.push({ id: selected, name: 'Colaborador selecionado no dossiê', employee_number: '' });
      }
      query('[name=employeeId]').innerHTML = '<option value="">Todos os colaboradores</option>' + list.map(person =>
        `<option value="${E(person.id)}" ${person.id === selected ? 'selected' : ''}>${E(person.name)}${person.employee_number ? ' · ' + E(person.employee_number) : ''}</option>`).join('');
    }

    function filters() {
      return {
        companyId: value('[name=companyId]'), employeeId: value('[name=employeeId]'),
        employeeNumber: value('[name=employeeNumber]').trim(), dateFrom: value('[name=dateFrom]'), dateTo: value('[name=dateTo]'), status: value('[name=status]'), followupStatus: value('[name=followupStatus]'),
      };
    }

    function validSummary(data) {
      const keys = ['total','complete','incomplete','people','untracked','open','inProgress','concluded'];
      return data && keys.every(key => Number.isSafeInteger(data[key]) && data[key] >= 0) &&
        data.complete + data.incomplete === data.total && data.people <= data.total &&
        data.untracked + data.open + data.inProgress + data.concluded === data.total;
    }

    function drawSummary() {
      const node = query('[data-attention-dashboard]');
      if (!summary) { node.innerHTML = '<p class="platform-note">Os indicadores serão exibidos após a consulta.</p>'; return; }
      const s = summary;
      const pie = (label, slices) => {
        let end = 0;
        const stops = slices.map(slice => { const start=end;end+=s.total ? slice[1]/s.total*100 : 0;return slice[2]+' '+start+'% '+end+'%'; });
        const description = slices.map(([name,n]) => name+': '+number(n)).join('; ');
        return `<section class="attention-chart"><h3>${E(label)}</h3><div class="attention-chart-content"><div class="attention-pie ${s.total ? '' : 'empty'}" role="img" aria-label="${E(label+': '+description)}" style="background:${s.total ? 'conic-gradient('+stops.join(',')+')' : '#e6edf3'}"></div><ul>${slices.map(([name,n,color]) => `<li><span class="attention-legend" style="background:${color}" aria-hidden="true"></span><span>${E(name)}</span><strong>${E(number(n))}</strong></li>`).join('')}</ul></div></section>`;
      };
      node.innerHTML = `<div class="attention-kpis" aria-label="Indicadores de todas as avaliações filtradas">${[['Avaliações recebidas',s.total],['Colaboradores',s.people],['Avaliações completas',s.complete],['Acompanhamentos em aberto',s.open+s.inProgress]].map(([label,n])=>`<article><span>${E(label)}</span><strong>${E(number(n))}</strong></article>`).join('')}</div><div class="attention-charts">${pie('Conclusão das avaliações',[['Completas',s.complete,'#245c98'],['Incompletas',s.incomplete,'#d4a24b']])}${pie('Acompanhamento pela gestão',[['Sem acompanhamento',s.untracked,'#a5b4c4'],['Aberto',s.open,'#b87438'],['Em andamento',s.inProgress,'#317cc1'],['Concluído',s.concluded,'#39826b']])}</div><p class="platform-note">Indicadores de todos os registros encontrados com os filtros aplicados. Conclusão e acompanhamento são controles operacionais; não definem aptidão para condução.</p>`;
    }

    function validAssessment(row, cid) {
      return row && typeof row.id === 'string' && row.company_id === cid &&
        ['completa', 'incompleta'].includes(row.status) && row.metrics &&
        typeof row.metrics === 'object' && !Array.isArray(row.metrics);
    }

    function invalidateFilters(companyChanged) {
      if (!current()) return;
      ++listToken;
      closeDetail();
      rows = [];
      summary = null;
      nextOffset = null;
      if (companyChanged) personOptions();
      query('[data-attention-results]').replaceChildren();
      drawSummary();
      query('[data-attention-count]').textContent = '';
      query('[data-attention-more]').hidden = true;
      query('[data-attention-apply]').disabled = false;
      status('Filtros alterados. Selecione Aplicar filtros para consultar.');
    }

    function drawRows() {
      if (!current()) return;
      query('[data-attention-count]').textContent = rows.length + ' de ' + (summary ? number(summary.total) : '—') + ' avaliação(ões) carregada(s).';
      query('[data-attention-results]').innerHTML = rows.map((row, index) => {
        const metrics = row.metrics;
        const visual = row.protocol_version === 'visual-v1';
        const targets = visual ? number(metrics.encerrados) + ' / ' + number(metrics.previstos) : numeric(metrics.acertos) && numeric(metrics.total_alvos)
          ? number(metrics.acertos) + ' / ' + number(metrics.total_alvos) : '—';
        return `<article class="platform-card attention-card" data-attention-id="${E(row.id)}">
          <div class="attention-card-heading"><h3>${E(row.employee_name || 'Colaborador')}</h3><span class="attention-state ${row.status === 'incompleta' ? 'partial' : ''}">${state(row.status)}</span></div>
          <p>Matrícula ${E(text(row.employee_number))} · ${E(companyMap.get(row.company_id)?.name || 'Empresa deste acesso')}<br>${E(timestamp(row.started_at))} · ${E(moment(row.moment))}</p>
          <dl class="attention-measurements compact"><div><dt>Duração</dt><dd>${E(time(row.duration_ms))}</dd></div><div><dt>${visual ? 'Apresentações encerradas' : 'Alvos concluídos'}</dt><dd>${E(targets)}</dd></div><div><dt>${visual ? 'Reação mediana' : 'Erros de sequência'}</dt><dd>${E(visual ? time(metrics.mediana_reacao_ms) : number(metrics.erros))}</dd></div></dl>
          ${row.status === 'incompleta' ? '<p class="attention-partial">Avaliação encerrada antes da conclusão. As métricas são parciais.</p>' : ''}
          <p class="platform-note">Aplicativo ${E(text(row.app_version))} · protocolo ${E(text(row.protocol_version))}</p>
          ${visual ? `<p>Classificação experimental: <strong>${E(metrics.classification?.level || (metrics.classification?.state==='base_em_formacao'?'Base em formação':metrics.classification?.state==='qualidade_insuficiente'?'Qualidade técnica insuficiente':'Referência insuficiente'))}</strong></p>` : ''}
          <p class="attention-followup-label">Acompanhamento: <strong>${E(followupState(row.followup_status))}</strong></p>
          <button type="button" data-attention-detail="${index}">Consultar avaliação</button>
        </article>`;
      }).join('') || '<p class="attention-empty">Nenhuma avaliação encontrada neste acesso e período. A ausência de registro não indica descumprimento.</p>';
      query('[data-attention-more]').hidden = nextOffset === null;
      query('[data-attention-more]').disabled = false;
      container.querySelectorAll('[data-attention-detail]').forEach(button => {
        button.onclick = () => openDetail(rows[Number(button.dataset.attentionDetail)]);
      });
    }

    async function load(append = false, keepDetail = false) {
      if (!current()) return;
      const selected = filters();
      if (!companyMap.has(selected.companyId)) return status('Selecione uma empresa deste acesso.', true);
      if (selected.dateFrom && selected.dateTo && selected.dateFrom > selected.dateTo) {
        return status('A data inicial está depois da data final. Ajuste o período.', true);
      }
      const offset = append ? nextOffset : 0;
      if (append && offset === null) return;
      const expected = ++listToken;
      if (!keepDetail) closeDetail();
      if (!append) {
        rows = [];
        summary = null;
        drawSummary();
        nextOffset = null;
        query('[data-attention-results]').replaceChildren();
        query('[data-attention-count]').textContent = '';
      }
      query('[data-attention-more]').hidden = true;
      query('[data-attention-apply]').disabled = true;
      status(append ? 'Carregando mais avaliações…' : 'Consultando histórico central…');
      try {
        const data = await PR.call('attention-dashboard-list', { ...selected, offset, limit: 50 }, true);
        if (!current() || expected !== listToken) return;
        if (!Array.isArray(data?.rows) || !Number.isInteger(data.moduleVersion) || data.moduleVersion < 54 || !validSummary(data.summary) ||
            data.rows.some(row => !validAssessment(row, selected.companyId)) ||
            (data.nextOffset !== null && (!Number.isInteger(data.nextOffset) || data.nextOffset <= offset))) {
          throw Error('O histórico retornou uma resposta inválida. Atualize a consulta ou solicite a ativação do módulo.');
        }
        const combined = append ? [...rows, ...data.rows] : data.rows;
        rows = [...new Map(combined.map(row => [row.id, row])).values()];
        nextOffset = data.nextOffset;
        summary = data.summary;
        drawSummary();
        for (const row of data.rows) {
          const key = row.company_id + ':' + row.employee_id;
          if (row.employee_id && !people.has(key)) people.set(key, {
            id: row.employee_id, company_id: row.company_id,
            name: row.employee_name || 'Colaborador do histórico', employee_number: row.employee_number,
          });
        }
        personOptions(selected.employeeId);
        status('Consulta central concluída. Horários apresentados no fuso de Fortaleza.');
        drawRows();
      } catch (error) {
        if (!current() || expected !== listToken) return;
        status(error.message || 'Não foi possível consultar o histórico. Tente novamente.', true);
        if (append) {
          query('[data-attention-more]').hidden = false;
          query('[data-attention-more]').disabled = false;
        }
      } finally {
        if (current() && expected === listToken) query('[data-attention-apply]').disabled = false;
      }
    }

    async function openDetail(row) {
      if (!current() || !row) return;
      closeDetail();
      const expected = ++detailToken;
      const selectedDialog = document.createElement('dialog');
      selectedDialog.className = 'attention-dialog';
      selectedDialog.innerHTML = '<header><h2>Detalhe da avaliação de atenção</h2><button type="button" data-attention-close>Fechar</button></header><div class="attention-dialog-body"><p role="status">Carregando avaliação…</p></div>';
      dialog = selectedDialog;
      document.body.append(selectedDialog);
      const active = () => current() && dialog === selectedDialog && expected === detailToken && selectedDialog.isConnected;
      selectedDialog.querySelector('[data-attention-close]').onclick = closeDetail;
      selectedDialog.addEventListener('close', () => {
        if (dialog === selectedDialog) { dialog = null; ++detailToken; }
        selectedDialog.remove();
      });
      selectedDialog.showModal();
      const body = selectedDialog.querySelector('.attention-dialog-body');
      async function fetchDetail() {
        if (!active()) return;
        body.innerHTML = '<p role="status">Carregando avaliação…</p>';
        try {
          const data = await PR.call('attention-history-detail', { companyId: row.company_id, id: row.id, visualVersion: 1 }, true);
          if (!active()) return;
          const assessment = data?.assessment;
          if (!Number.isInteger(data.moduleVersion) || data.moduleVersion < 51 ||
              !validAssessment(assessment, row.company_id) || assessment.id !== row.id ||
              (assessment.protocol_version === 'visual-v1'
                ? !Array.isArray(assessment.trials) || !Array.isArray(assessment.responses) || !Array.isArray(assessment.schedule)
                : !Array.isArray(assessment.touches) || !Array.isArray(assessment.grid))) {
            throw Error('Não foi possível conferir os dados desta avaliação. Tente novamente.');
          }
          const metrics = assessment.metrics;
          const visual = assessment.protocol_version === 'visual-v1';
          const fields = visual ? [
            ['Duração registrada', time(assessment.duration_ms)],
            ['Apresentações encerradas', number(metrics.encerrados) + ' / ' + number(metrics.previstos)],
            ['Respostas ao círculo parado', number(metrics.respostas_validas)],
            ['Sem resposta ao círculo parado', number(metrics.omissoes)],
            ['Toques no círculo em movimento', number(metrics.comissoes)],
            ['Toques fora da apresentação', number(metrics.fora_estimulo)],
            ['Toques adicionais na mesma apresentação', number(metrics.toques_extras)],
            ['Reação mediana', time(metrics.mediana_reacao_ms)],
            ['Média dos 10% mais rápidos', time(metrics.rapidos10_media_ms)],
            ['Média dos 10% mais lentos', time(metrics.lentos10_media_ms)],
            ['Lapsos (reação acima de 500 ms)',number(metrics.lapsos)],
            ['Antecipações (fora do estímulo ou abaixo de 100 ms)',number(metrics.antecipacoes)],
            ['Declínio: último menos primeiro quarto',number(metrics.declinio_ms)+' ms'],
            ['Reação média', time(metrics.media_reacao_ms)],
            ['Desvio dos tempos de reação', time(metrics.dp_reacao_ms)],
            ['Percentil 10', time(metrics.p10_reacao_ms)], ['Percentil 90', time(metrics.p90_reacao_ms)],
            ['Maior atraso de apresentação/fechamento observado', time(metrics.maior_atraso_ms)],
          ] : [
            ['Duração registrada', time(assessment.duration_ms)],
            ['Tempo até o primeiro toque', time(metrics.tempo_primeiro_toque_ms)],
            ['Alvos concluídos', number(metrics.acertos)], ['Total de alvos', number(metrics.total_alvos)],
            ['Erros de sequência', number(metrics.erros)],
            ['Intervalo médio entre acertos', time(metrics.media_intervalo_ms)],
            ['Desvio dos intervalos', time(metrics.dp_intervalo_ms)],
          ];
          const quartiles = Array.isArray(metrics.quartis_ms) ? metrics.quartis_ms.slice(0, 4) : [];
          const touches = Array.isArray(assessment.touches) ? assessment.touches : [];
          body.innerHTML = `<div class="attention-card-heading"><h3>${E(assessment.employee_name || 'Colaborador')}</h3><span class="attention-state ${assessment.status === 'incompleta' ? 'partial' : ''}">${state(assessment.status)}</span></div>
            <p>Matrícula ${E(text(assessment.employee_number))} · ${E(text(assessment.job_title))}<br>${E(companyMap.get(assessment.company_id)?.name || 'Empresa deste acesso')} · ${E(text(assessment.unit))} / ${E(text(assessment.team))}</p>
            ${assessment.status === 'incompleta' ? '<p class="attention-partial">Avaliação incompleta. Os valores abaixo representam somente o trecho registrado.</p>' : ''}
            <dl class="attention-metadata"><div><dt>Iniciada em</dt><dd>${E(timestamp(assessment.started_at))}</dd></div><div><dt>Encerrada em</dt><dd>${E(timestamp(assessment.finished_at))}</dd></div><div><dt>Momento</dt><dd>${E(moment(assessment.moment))}</dd></div><div><dt>Recebida na plataforma</dt><dd>${E(timestamp(assessment.received_at))}</dd></div><div><dt>Versão do aplicativo</dt><dd>${E(text(assessment.app_version))}</dd></div><div><dt>Versão do protocolo</dt><dd>${E(text(assessment.protocol_version))}</dd></div></dl>
            ${visual ? classification(metrics) : ''}<h3>Métricas registradas</h3><dl class="attention-measurements">${fields.map(([label, result]) => `<div><dt>${E(label)}</dt><dd>${E(result)}</dd></div>`).join('')}</dl>
            ${visual ? `<h3>Reação média por quarto da avaliação</h3><dl class="attention-measurements quartiles">${[0,1,2,3].map(i=>`<div><dt>Bloco ${i+1}</dt><dd>${E(time(metrics.quartos_media_ms?.[i]))}</dd></div>`).join('')}</dl><p class="platform-note">Protocolo visual em validação. Valores observados, sem diagnóstico ou liberação para condução. Não há compensação da latência física da tela ou do toque.</p><p>${E(assessment.interruption || '')}</p><details class="attention-touches"><summary>Apresentações registradas (${assessment.trials.length})</summary><div class="table-scroll"><table class="platform-table"><thead><tr><th>Ordem</th><th>Estímulo</th><th>Exibido</th><th>Encerrado</th></tr></thead><tbody>${assessment.trials.map(t=>`<tr><td>${E(t.seq)}</td><td>${assessment.schedule[t.seq-1]?.kind==='go'?'Parado':'Em movimento'}</td><td>${E(time(t.shownMs))}</td><td>${E(time(t.closedMs))}</td></tr>`).join('')}</tbody></table></div></details><details class="attention-touches"><summary>Respostas registradas (${assessment.responses.length})</summary><div class="table-scroll"><table class="platform-table"><thead><tr><th>Ordem</th><th>Instante</th><th>Entrada</th></tr></thead><tbody>${assessment.responses.map(r=>`<tr><td>${E(r.seq)}</td><td>${E(time(r.tMs))}</td><td>${r.source==='keyboard'?'Teclado':'Toque/clique'}</td></tr>`).join('')}</tbody></table></div></details>` : `<h3>Tempo por bloco da sequência</h3><dl class="attention-measurements quartiles">${[0, 1, 2, 3].map(index => `<div><dt>Bloco ${index + 1}</dt><dd>${E(time(quartiles[index]))}</dd></div>`).join('')}</dl><p class="platform-note">Um bloco não concluído aparece como —. Estes registros não representam liberação para condução.</p>
            <details class="attention-touches"><summary>Consultar toques registrados (${touches.length})</summary><div class="table-scroll"><table class="platform-table"><thead><tr><th>Ordem</th><th>Instante</th><th>Número tocado</th><th>Esperado</th><th>Registro</th></tr></thead><tbody>${touches.map(touch => `<tr><td>${E(number(touch.seq))}</td><td>${E(time(touch.tMs))}</td><td>${E(number(touch.touched))}</td><td>${E(number(touch.expected))}</td><td>${touch.correct === true ? 'Acerto' : touch.correct === false ? 'Erro' : '—'}</td></tr>`).join('')}</tbody></table></div>${touches.length ? '' : '<p>Nenhum toque informado nesta avaliação.</p>'}</details>`}
            <p class="platform-note attention-record-id">ID da avaliação: ${E(assessment.id)}</p><section class="attention-followup" data-attention-followup><h3>Acompanhamento pela gestão</h3><p role="status">Carregando acompanhamento…</p></section>`;
          await loadFollowup();
        } catch (error) {
          if (!active()) return;
          body.innerHTML = '<p role="alert">' + E(error.message || 'Não foi possível carregar a avaliação.') + '</p><button type="button" data-attention-retry>Tentar novamente</button>';
          body.querySelector('[data-attention-retry]').onclick = fetchDetail;
        }
      }

      async function loadFollowup() {
        if (!active()) return;
        const area = body.querySelector('[data-attention-followup]');
        if (!area) return;
        try {
          const data = await PR.call('attention-followup-detail', {companyId:row.company_id,id:row.id}, true);
          if (!active() || !area.isConnected) return;
          renderFollowup(area, data);
        } catch (error) {
          if (!active() || !area.isConnected) return;
          area.innerHTML = '<h3>Acompanhamento pela gestão</h3><p role="alert">'+E(error.message || 'Não foi possível consultar o acompanhamento.')+'</p><button type="button" data-followup-retry>Tentar novamente</button>';
          area.querySelector('[data-followup-retry]').onclick = loadFollowup;
        }
      }

      function renderFollowup(area, data) {
        if (!Number.isInteger(data?.moduleVersion) || data.moduleVersion < 54 || !Array.isArray(data.events) ||
            data.events.some(event => event.assessment_id !== row.id || event.company_id !== row.company_id || !Number.isSafeInteger(event.revision) || event.revision < 1 || !['aberta','em_andamento','concluida'].includes(event.status)) ||
            (data.current === null ? data.events.length !== 0 : (!data.current || data.current.assessment_id !== row.id || data.current.company_id !== row.company_id || !Number.isSafeInteger(data.current.revision) || !['aberta','em_andamento','concluida'].includes(data.current.status) || data.events[0]?.revision !== data.current.revision || data.events[0]?.status !== data.current.status))) {
          throw Error('Não foi possível conferir o acompanhamento desta avaliação. Atualize a consulta.');
        }
        const revision = data.current?.revision || 0;
        area.innerHTML = `<h3>Acompanhamento pela gestão</h3><p class="platform-note">Registre orientações e providências operacionais. Não inclua diagnósticos ou prontuários. Este acompanhamento não altera o resultado da avaliação.</p><p>Situação atual: <strong>${E(followupState(data.current?.status))}</strong></p>
          <form data-followup-form><label>Situação do acompanhamento<select name="followupState"><option value="aberta">Aberto</option><option value="em_andamento">Em andamento</option><option value="concluida">Concluído</option></select></label><label>Descrição da atualização<textarea name="followupNote" maxlength="4000" rows="4" required placeholder="Descreva a orientação, providência ou conclusão."></textarea></label><div class="attention-filter-actions"><button type="submit">Salvar acompanhamento</button><button type="button" data-followup-refresh>Atualizar acompanhamento</button></div><p data-followup-message role="status" aria-live="polite"></p></form>
          <details class="attention-followup-history"><summary>Histórico do acompanhamento (${data.events.length})</summary>${data.events.map(event=>`<article><div class="attention-card-heading"><strong>${E(followupState(event.status))}</strong><span>Revisão ${E(event.revision)}</span></div><p class="attention-followup-note">${E(event.note)}</p><p class="platform-note">${E(event.actor_name || 'Gestor autorizado')} · ${E(timestamp(event.created_at))}</p></article>`).join('') || '<p>Nenhum acompanhamento registrado.</p>'}</details>`;
        const form = area.querySelector('[data-followup-form]');
        form.elements.followupState.value = data.current?.status || 'aberta';
        area.querySelector('[data-followup-refresh]').onclick = loadFollowup;
        form.onsubmit = async event => {
          event.preventDefault();
          const note = form.elements.followupNote.value.trim(), message = form.querySelector('[data-followup-message]');
          if (!note) { message.setAttribute('role','alert');message.textContent='Descreva a atualização do acompanhamento.';return; }
          const button = form.querySelector('[type=submit]'), refresh = form.querySelector('[data-followup-refresh]');
          if (button.disabled) return;
          button.disabled = true;refresh.disabled = true;
          message.setAttribute('role','status');message.textContent='Salvando acompanhamento…';
          try {
            const result = await PR.call('attention-followup-save', {companyId:row.company_id,id:row.id,status:form.elements.followupState.value,note,expectedRevision:revision}, true);
            if (!active() || !area.isConnected) return;
            renderFollowup(area, result);
            const done = area.querySelector('[data-followup-message]');done.textContent='Acompanhamento salvo. O resultado original foi preservado.';
            await load(false, true);
          } catch (error) {
            if (!active() || !area.isConnected) return;
            message.setAttribute('role','alert');message.textContent=error.message || 'Não foi possível confirmar o salvamento. Atualize o acompanhamento antes de tentar novamente.';
          } finally {
            if (active() && form.isConnected) { button.disabled=false;refresh.disabled=false; }
          }
        };
      }
      await fetchDetail();
    }

    async function configurationPanel() {
      if(!canConfigure || !current())return;
      let panel=query('[data-rules]');
      if(!panel){panel=document.createElement('details');panel.dataset.rules='';panel.className='platform-box';panel.innerHTML='<summary>Configuração da classificação experimental</summary><div data-rules-body></div>';container.prepend(panel);}
      let loaded=false;
      panel.ontoggle=async()=>{
        if(!panel.open){loaded=false;return;}
        if(loaded || !current())return;
        const area=panel.querySelector('[data-rules-body]'),cid=value('[name=companyId]');loaded=true;
        area.innerHTML='<p role="status">Consultando configuração…</p>';
        try{
          const data=await PR.call('attention-rules-get',{companyId:cid},true);
          if(!current() || cid!==value('[name=companyId]')){loaded=false;return;}
          const cfg=data.config;
          const fields=[['z1','Limite z para Normal',.1,10,.1],['z2','Limite z para Limítrofe',.1,10,.1],['z3','Limite z para Alterado',.1,10,.1],['habituation','Testes de habituação excluídos',0,100,1],['individualMinimum','Mínimo de testes individuais',2,100,1],['individualWindow','Janela móvel individual',2,100,1],['populationMinimum','Mínimo de testes populacionais',2,5000,1],['populationPeople','Mínimo de outras pessoas na base',2,100,1],['maxExtraResponses','Máximo de entradas fora da regra',0,500,1],['maxTimingDelayMs','Maior atraso técnico aceitável (ms)',10,1000,1],['recurrenceWindow','Janela de recorrência (testes)',2,30,1],['recurrenceMinimum','Resultados fora de Normal para recorrência',2,30,1]];
          area.innerHTML=`<p>Revisão ${E(data.revision)}. Ajustes valem somente para novas avaliações. Os parâmetros precisam de validação pela equipe responsável; permanecem identificados como experimentais.</p><p>O nível final considera o maior z de piora entre os parâmetros e as duas bases. Referências sem amostra ou sem dispersão suficiente não recebem Normal por padrão.</p><form class="attention-filters">${fields.map(([key,label,min,max,step])=>`<label>${E(label)}<input type="number" name="${key}" min="${min}" max="${max}" step="${step}" value="${E(cfg[key])}" required></label>`).join('')}<label>Base populacional<select name="segment"><option value="job_title">Mesma função/cargo na empresa</option><option value="company">Toda a empresa</option></select></label><button type="submit">Salvar parâmetros</button><p data-rules-message role="status"></p></form><p class="platform-note">Sem mistura de empresas ou protocolos. Limiares de coleta deste protocolo: antecipação abaixo de 100 ms, lapso acima de 500 ms. Sensores e questionários de saúde permanecem desativados. Não há liberação ou bloqueio automático.</p>`;
          const form=area.querySelector('form');form.elements.segment.value=cfg.segment;
          form.onsubmit=async event=>{
            event.preventDefault();const button=form.querySelector('button'),message=form.querySelector('[data-rules-message]');
            if(button.disabled)return;
            const config={...cfg,segment:form.elements.segment.value};for(const [key]of fields)config[key]=Number(form.elements[key].value);
            button.disabled=true;message.textContent='Salvando configuração…';
            try{const result=await PR.call('attention-rules-save',{companyId:cid,config,expectedRevision:data.revision},true);
              if(!current() || cid!==value('[name=companyId]'))return;
              data.revision=result.revision;Object.assign(cfg,result.config);message.textContent='Parâmetros salvos na revisão '+result.revision+'. Avaliações anteriores mantêm sua classificação original.';
            }catch(error){if(current())message.textContent=error.message||'Não foi possível salvar. Reabra esta área para consultar a versão atual.';}
            finally{if(current()&&form.isConnected)button.disabled=false;}
          };
        }catch(error){if(current())area.textContent=error.message||'Configuração indisponível.';loaded=false;}
      };
    }

    return {
      async open(employeeId = '') {
        if (!current()) return;
        container.innerHTML = `<section class="platform-box"><h2>Sistema Apto</h2><p>Acompanhe as avaliações de atenção recebidas do aplicativo, por colaborador e período. Registros pendentes no aparelho aparecem após a confirmação do envio.</p><p><a class="attention-open-app" href="triagem/" target="_blank" rel="noopener">Abrir aplicativo de avaliações</a></p>
          <form class="attention-filters"><label>Empresa<select name="companyId">${[...companyMap.values()].map(item => `<option value="${E(item.id)}" ${item.id === company.id ? 'selected' : ''}>${E(item.name)}</option>`).join('')}</select></label><label>Colaborador<select name="employeeId"></select></label><label>Matrícula exata<input name="employeeNumber" type="text" maxlength="160" placeholder="Todas as matrículas"></label><label>Data inicial<input name="dateFrom" type="date"></label><label>Data final<input name="dateTo" type="date"></label><label>Situação da avaliação<select name="status"><option value="">Todas</option><option value="completa">Completa</option><option value="incompleta">Incompleta</option></select></label><label>Acompanhamento<select name="followupStatus"><option value="">Todos</option><option value="sem_acompanhamento">Sem acompanhamento</option><option value="aberta">Aberto</option><option value="em_andamento">Em andamento</option><option value="concluida">Concluído</option></select></label><div class="attention-filter-actions"><button type="submit" data-attention-apply>Aplicar filtros</button><button type="button" class="secondary" data-attention-clear>Limpar filtros</button></div></form>
          <p data-attention-status role="status" aria-live="polite"></p><div data-attention-dashboard aria-label="Indicadores do Sistema Apto"></div><h3 class="attention-results-title">Avaliações recebidas</h3><p data-attention-count class="platform-note"></p><div data-attention-results></div><button type="button" data-attention-more hidden>Carregar mais avaliações</button></section>`;
        host.replaceChildren(container);
        configurationPanel();
        personOptions(employeeId);
        query('form').onsubmit = event => { event.preventDefault(); load(); };
        container.querySelectorAll('.attention-filters input,.attention-filters select').forEach(input => {
          input.oninput = () => { invalidateFilters(input.name === 'companyId'); if(input.name==='companyId'){query('[data-rules]')?.remove();configurationPanel();} };
        });
        query('[data-attention-clear]').onclick = () => {
          query('[name=companyId]').value = company.id;
          personOptions();
          for (const name of ['employeeNumber','dateFrom', 'dateTo', 'status','followupStatus']) query('[name=' + name + ']').value = '';
          load();
        };
        query('[data-attention-more]').onclick = () => load(true);
        await load();
      },
      destroy() {
        alive = false;
        ++listToken;
        closeDetail();
        rows = [];
        people.clear();
        container.remove();
      },
    };
  }
  return { create };
})();
