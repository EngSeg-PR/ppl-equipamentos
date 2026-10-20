const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const currentModel = JSON.parse(read('ppl-inspection-model.json'));
const sourceSql = read('supabase/modelos-ppl-v42/cadastrar-inspecao.sql');
const historicalModel = JSON.parse(sourceSql.match(/\$model\$([\s\S]+?)\$model\$/)[1]);
const removedFields = ['areaResponsible', 'areaEmployee', 'areaDepartment'];

assert.equal(currentModel.version, '2');
assert.equal(currentModel.identifiers.length, historicalModel.identifiers.length - removedFields.length);
for (const field of removedFields) {
  assert(historicalModel.identifiers.some(f => f.name === field));
  assert(!currentModel.identifiers.some(f => f.name === field));
}
assert.deepEqual(currentModel, {
  ...historicalModel,
  version: '2',
  identifiers: historicalModel.identifiers.filter(f => !removedFields.includes(f.name))
}, 'only the requested fields and model version may change');

const context = vm.createContext({
  window: { PRContext: { kind: 'inspection', models: [
    { snapshot: historicalModel, kind: 'inspection', active: false },
    { snapshot: { ...currentModel, version: 'wrong-kind' }, kind: 'checklist', active: true },
    { snapshot: currentModel, kind: 'inspection', active: true }
  ] } },
  MODEL: { id: 'default-belt', version: '1' },
  MODEL_VERSIONS: {}
});
vm.runInContext(read('models.js'), context);
context.historical = historicalModel;
context.latest = currentModel;
vm.runInContext('MODEL_REGISTRY.push(historical,latest)', context);
assert.equal(context.getModel(currentModel.id), currentModel,
  'new inspections must select active v2 even when inactive v1 is registered first');
assert.equal(context.knownSnapshot(historicalModel), historicalModel,
  'old offline records must resolve their exact original v1 snapshot');
assert.equal(context.knownSnapshot(currentModel), currentModel);
assert.equal(context.knownSnapshot({ id: currentModel.id, version: 'unknown' }), undefined);
delete context.window.PRContext;
assert.equal(context.getModel('default-belt').id, 'default-belt', 'legacy local mode stays available');
assert.equal(context.knownSnapshot(historicalModel), historicalModel, 'lookup never rewrites saved snapshots');

async function pdfText(model) {
  const output = [];
  const font = { widthOfTextAtSize: (text, size) => text.length * size * .45 };
  const doc = {
    embedFont: async () => font,
    addPage: () => ({ drawText: text => output.push(text), drawLine() {}, drawRectangle() {}, drawImage() {} }),
    setTitle() {}, save: () => new Uint8Array()
  };
  const sandbox = vm.createContext({
    PDFLib: { PDFDocument: { create: async () => doc }, StandardFonts: {}, rgb: (...rgb) => rgb },
    localTime: value => value
  });
  vm.runInContext(read('ppl-inspection.js'), sandbox);
  const fields = Object.fromEntries(model.identifiers.map(f => [f.name, 'QA']));
  Object.assign(fields, {
    date: '2026-10-20', time: '08:00', belt: 'LOCAL FICTÍCIO', unit: 'PORTO', team: 'PINTURA',
    inspector: 'PESSOA FICTÍCIA', employee: 'QA', functionName: 'TST',
    areaResponsible: 'RESPONSAVEL HISTORICO', areaEmployee: 'MATRICULA HISTORICA', areaDepartment: 'GERENCIA HISTORICA'
  });
  await sandbox.makePPLInspectionPDF({
    id: 'TESTE', revision: 1, model, fields,
    answers: [{ value: 'Conforme', notes: '', photos: [] }], recordedAt: '2026-10-20T08:00:00Z'
  });
  return output.join('\n');
}

async function sqlRegression() {
  if (!process.env.PRS_PGLITE_MODULE) return;
  const { PGlite } = require(process.env.PRS_PGLITE_MODULE);
  const db = new PGlite();
  try {
    await db.exec('CREATE TABLE public.ppl_companies(id uuid PRIMARY KEY,slug text); CREATE TABLE public.ppl_company_models(company_id uuid,model_id text,version text,kind text,snapshot jsonb,active boolean DEFAULT true,UNIQUE(company_id,model_id,version)); CREATE TABLE public.ppl_inspections(key text,payload jsonb);');
    const ppl = '00000000-0000-0000-0000-000000000001';
    const other = '00000000-0000-0000-0000-000000000002';
    await db.query('INSERT INTO public.ppl_companies VALUES ($1,$2),($3,$4)', [ppl, 'ppl', other, 'other']);
    for (const company of [ppl, other]) await db.query('INSERT INTO public.ppl_company_models VALUES ($1,$2,$3,$4,$5,true)',
      [company, historicalModel.id, '1', 'inspection', JSON.stringify(historicalModel)]);
    const oldRecord = { model: historicalModel, fields: { areaResponsible: 'ORIGINAL FICTÍCIO' } };
    await db.query('INSERT INTO public.ppl_inspections VALUES ($1,$2)', ['old:1', JSON.stringify(oldRecord)]);
    const sql = read('supabase/ajustes-v46/inspecao-ppl-v2.sql');
    await db.exec(sql);
    await db.exec(sql);
    const rows = (await db.query('SELECT * FROM public.ppl_company_models')).rows;
    assert.equal(rows.length, 3, 'migration must be idempotent');
    const old = rows.find(row => row.company_id === ppl && row.version === '1');
    const latest = rows.find(row => row.company_id === ppl && row.version === '2');
    assert.equal(old.active, false);
    assert.deepEqual(old.snapshot, historicalModel);
    assert.equal(latest.active, true);
    assert.deepEqual(latest.snapshot, currentModel);
    assert.equal(rows.find(row => row.company_id === other).active, true, 'other companies stay unchanged');
    assert.deepEqual((await db.query('SELECT payload FROM public.ppl_inspections')).rows[0].payload, oldRecord);
    await db.query("UPDATE public.ppl_company_models SET snapshot='{}'::jsonb WHERE company_id=$1 AND version='2'", [ppl]);
    await assert.rejects(db.exec(sql), /outro snapshot/);
    await db.exec('ROLLBACK');
  } finally { await db.close(); }
}

(async () => {
  const latest = await pdfText(currentModel);
  const historical = await pdfText(historicalModel);
  assert(latest.includes('Gerência: QA'), 'general inspection management stays');
  for (const value of ['Responsável pela área:', 'RESPONSAVEL HISTORICO', 'MATRICULA HISTORICA', 'GERENCIA HISTORICA']) {
    assert(!latest.includes(value), 'removed fields do not leak into new PDFs');
    assert(historical.includes(value), 'historical PDFs retain the original field values');
  }
  await sqlRegression();
  console.log('PASS inspection v2: active model selection, exact historical/offline lookup, three field removals, old PDF data preservation' + (process.env.PRS_PGLITE_MODULE ? ', idempotent tenant-scoped SQL and collision protection' : ''));
})().catch(error => { console.error(error); process.exitCode = 1; });
