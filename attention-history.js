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

  function create({ host, company, companies = [company], employees = [], isCurrent = () => true }) {
    if (!host || !company?.id) throw Error('Empresa ou área de consulta indisponível.');
    let alive = true, listToken = 0, detailToken = 0, rows = [], nextOffset = null, dialog = null;
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
        dateFrom: value('[name=dateFrom]'), dateTo: value('[name=dateTo]'), status: value('[name=status]'),
      };
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
      nextOffset = null;
      if (companyChanged) personOptions();
      query('[data-attention-results]').replaceChildren();
      query('[data-attention-count]').textContent = '';
      query('[data-attention-more]').hidden = true;
      query('[data-attention-apply]').disabled = false;
      status('Filtros alterados. Selecione Aplicar filtros para consultar.');
    }

    function drawRows() {
      if (!current()) return;
      query('[data-attention-count]').textContent = rows.length + ' avaliação(ões) carregada(s).';
      query('[data-attention-results]').innerHTML = rows.map((row, index) => {
        const metrics = row.metrics;
        const targets = numeric(metrics.acertos) && numeric(metrics.total_alvos)
          ? number(metrics.acertos) + ' / ' + number(metrics.total_alvos) : '—';
        return `<article class="platform-card attention-card" data-attention-id="${E(row.id)}">
          <div class="attention-card-heading"><h3>${E(row.employee_name || 'Colaborador')}</h3><span class="attention-state ${row.status === 'incompleta' ? 'partial' : ''}">${state(row.status)}</span></div>
          <p>Matrícula ${E(text(row.employee_number))} · ${E(companyMap.get(row.company_id)?.name || 'Empresa deste acesso')}<br>${E(timestamp(row.started_at))} · ${E(moment(row.moment))}</p>
          <dl class="attention-measurements compact"><div><dt>Duração</dt><dd>${E(time(row.duration_ms))}</dd></div><div><dt>Alvos concluídos</dt><dd>${E(targets)}</dd></div><div><dt>Erros de sequência</dt><dd>${E(number(metrics.erros))}</dd></div></dl>
          ${row.status === 'incompleta' ? '<p class="attention-partial">Avaliação encerrada antes da conclusão. As métricas são parciais.</p>' : ''}
          <p class="platform-note">Aplicativo ${E(text(row.app_version))} · protocolo ${E(text(row.protocol_version))}</p>
          <button type="button" data-attention-detail="${index}">Consultar avaliação</button>
        </article>`;
      }).join('') || '<p class="attention-empty">Nenhuma avaliação encontrada neste acesso e período. A ausência de registro não indica descumprimento.</p>';
      query('[data-attention-more]').hidden = nextOffset === null;
      query('[data-attention-more]').disabled = false;
      container.querySelectorAll('[data-attention-detail]').forEach(button => {
        button.onclick = () => openDetail(rows[Number(button.dataset.attentionDetail)]);
      });
    }

    async function load(append = false) {
      if (!current()) return;
      const selected = filters();
      if (!companyMap.has(selected.companyId)) return status('Selecione uma empresa deste acesso.', true);
      if (selected.dateFrom && selected.dateTo && selected.dateFrom > selected.dateTo) {
        return status('A data inicial está depois da data final. Ajuste o período.', true);
      }
      const offset = append ? nextOffset : 0;
      if (append && offset === null) return;
      const expected = ++listToken;
      closeDetail();
      if (!append) {
        rows = [];
        nextOffset = null;
        query('[data-attention-results]').replaceChildren();
        query('[data-attention-count]').textContent = '';
      }
      query('[data-attention-more]').hidden = true;
      query('[data-attention-apply]').disabled = true;
      status(append ? 'Carregando mais avaliações…' : 'Consultando histórico central…');
      try {
        const data = await PR.call('attention-history-list', { ...selected, offset, limit: 50 }, true);
        if (!current() || expected !== listToken) return;
        if (!Array.isArray(data?.rows) || !Number.isInteger(data.moduleVersion) || data.moduleVersion < 51 ||
            data.rows.some(row => !validAssessment(row, selected.companyId)) ||
            (data.nextOffset !== null && (!Number.isInteger(data.nextOffset) || data.nextOffset <= offset))) {
          throw Error('O histórico retornou uma resposta inválida. Atualize a consulta ou solicite a ativação do módulo.');
        }
        const combined = append ? [...rows, ...data.rows] : data.rows;
        rows = [...new Map(combined.map(row => [row.id, row])).values()];
        nextOffset = data.nextOffset;
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
          const data = await PR.call('attention-history-detail', { companyId: row.company_id, id: row.id }, true);
          if (!active()) return;
          const assessment = data?.assessment;
          if (!Number.isInteger(data.moduleVersion) || data.moduleVersion < 51 ||
              !validAssessment(assessment, row.company_id) || assessment.id !== row.id ||
              !Array.isArray(assessment.touches) || !Array.isArray(assessment.grid)) {
            throw Error('Não foi possível conferir os dados desta avaliação. Tente novamente.');
          }
          const metrics = assessment.metrics;
          const fields = [
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
            <h3>Métricas registradas</h3><dl class="attention-measurements">${fields.map(([label, result]) => `<div><dt>${E(label)}</dt><dd>${E(result)}</dd></div>`).join('')}</dl>
            <h3>Tempo por bloco da sequência</h3><dl class="attention-measurements quartiles">${[0, 1, 2, 3].map(index => `<div><dt>Bloco ${index + 1}</dt><dd>${E(time(quartiles[index]))}</dd></div>`).join('')}</dl><p class="platform-note">Um bloco não concluído aparece como —. Estes registros não representam liberação para condução.</p>
            <details class="attention-touches"><summary>Consultar toques registrados (${touches.length})</summary><div class="table-scroll"><table class="platform-table"><thead><tr><th>Ordem</th><th>Instante</th><th>Número tocado</th><th>Esperado</th><th>Registro</th></tr></thead><tbody>${touches.map(touch => `<tr><td>${E(number(touch.seq))}</td><td>${E(time(touch.tMs))}</td><td>${E(number(touch.touched))}</td><td>${E(number(touch.expected))}</td><td>${touch.correct === true ? 'Acerto' : touch.correct === false ? 'Erro' : '—'}</td></tr>`).join('')}</tbody></table></div>${touches.length ? '' : '<p>Nenhum toque informado nesta avaliação.</p>'}</details>
            <p class="platform-note attention-record-id">ID da avaliação: ${E(assessment.id)}</p>`;
        } catch (error) {
          if (!active()) return;
          body.innerHTML = '<p role="alert">' + E(error.message || 'Não foi possível carregar a avaliação.') + '</p><button type="button" data-attention-retry>Tentar novamente</button>';
          body.querySelector('[data-attention-retry]').onclick = fetchDetail;
        }
      }
      await fetchDetail();
    }

    return {
      async open(employeeId = '') {
        if (!current()) return;
        container.innerHTML = `<section class="platform-box"><h2>Histórico de avaliações de atenção</h2><p>Consulte as avaliações recebidas do aplicativo, por colaborador e período. Registros ainda pendentes no aparelho aparecem depois da confirmação do envio.</p><p><a class="attention-open-app" href="triagem/" target="_blank" rel="noopener">Abrir aplicativo de avaliações</a></p>
          <form class="attention-filters"><label>Empresa<select name="companyId">${[...companyMap.values()].map(item => `<option value="${E(item.id)}" ${item.id === company.id ? 'selected' : ''}>${E(item.name)}</option>`).join('')}</select></label><label>Colaborador<select name="employeeId"></select></label><label>Data inicial<input name="dateFrom" type="date"></label><label>Data final<input name="dateTo" type="date"></label><label>Situação da avaliação<select name="status"><option value="">Todas</option><option value="completa">Completa</option><option value="incompleta">Incompleta</option></select></label><div class="attention-filter-actions"><button type="submit" data-attention-apply>Aplicar filtros</button><button type="button" class="secondary" data-attention-clear>Limpar filtros</button></div></form>
          <p data-attention-status role="status" aria-live="polite"></p><p data-attention-count class="platform-note"></p><div data-attention-results></div><button type="button" data-attention-more hidden>Carregar mais avaliações</button></section>`;
        host.replaceChildren(container);
        personOptions(employeeId);
        query('form').onsubmit = event => { event.preventDefault(); load(); };
        container.querySelectorAll('.attention-filters input,.attention-filters select').forEach(input => {
          input.oninput = () => invalidateFilters(input.name === 'companyId');
        });
        query('[data-attention-clear]').onclick = () => {
          query('[name=companyId]').value = company.id;
          personOptions();
          for (const name of ['dateFrom', 'dateTo', 'status']) query('[name=' + name + ']').value = '';
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
