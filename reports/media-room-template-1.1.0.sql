-- Media Room + Cinema estimate templates 1.1.0 (2026-11-09, 1410) — held for Bryn's OK (shared template table).
-- Fixes: CORE 1 £852 / Halo Touch £807 (prices were swapped); "Second Halo Touch" option → "Halo remote instead of Halo Touch" (−£313);
-- Lighting split into "Lighting — LED" (strip / drivers / cabling) + "Lighting control" (modules per circuit + programming, existing hub/keypads not charged);
-- media-room gains the Stretched Fabric section; both read stretched_fabric_spec / lighting_control and seed from a published design budget.
with ctl as (select '{"key":"control","title":"Control system","service_nn":"07","labour_label":"Programming and commissioning","rows":[{"qty":1,"label":"Control4 CORE 1 controller","sell_ex":852,"labour_h":2,"model_id":"C4-CORE1"},{"qty":1,"label":"Control4 Halo Touch remote","sell_ex":807,"labour_h":0.6,"model_id":"C4-HALO-TOUCH"},{"qty":1,"label":"Lighting control integration programming","sell_ex":248,"when":"lighting_control","labour_per":"line"},{"qty":1,"label":"Halo remote instead of Halo Touch","sell_ex":-313,"model_id":"C4-HALO","optional":true}]}'::jsonb j),
lc as (select '{"key":"lighting-control","title":"Lighting control","service_nn":"04","when":"lighting_control","note":"Existing hubs and keypads are retained and not charged — only new modules and programming.","rows":[{"qty":"circuits","label":"Dimmer modules — one per new LED circuit","sell_ex":180,"labour_h":0.5,"allowance":true},{"qty":1,"label":"Scene programming on the lighting system","sell_ex":248,"allowance":true}]}'::jsonb j),
fab as (select s from estimate_templates, jsonb_array_elements(template->'sections') s where kind='cinema' and s->>'key'='fabric')
update estimate_templates t set version = '1.1.0', updated_at = now(), template = (t.template - 'sections' - 'version')
  || jsonb_build_object('version', '1.1.0',
     'reads', '["cinema_design_summary","stretched_fabric_spec","led_spec","lighting_control","takeoff_summary"]'::jsonb,
     'designBudget', '["stretched_fabric_spec"]'::jsonb,
     'inputs', (t.template->'inputs') || (case when t.kind='media-room' then '[{"key":"fabric","kind":"bool","unit":"","label":"Fabric walls","default":0},{"key":"fabric_walls","max":4,"min":0,"step":1,"unit":"","label":"Fabric walls (of 4)","default":0}]'::jsonb else '[]'::jsonb end) || '[{"key":"lighting_control","kind":"bool","unit":"","label":"Lighting control system (Rako, Lutron…)","default":0},{"key":"circuits","min":0,"step":1,"unit":"","label":"New LED circuits","default":4}]'::jsonb,
     'progress', case when (t.template->'progress') @> '[{"app":"stretchedFabric"}]' then t.template->'progress' else (t.template->'progress') || '[{"app":"stretchedFabric","label":"Stretched Fabric","param":"pid"}]'::jsonb end,
     'sections', (select jsonb_agg(x.s order by x.o) from (
        select (select s from fab) s, 0 o where t.kind='media-room'
        union all select case when s->>'key'='control' then (select j from ctl) when s->>'key'='lighting' then jsonb_set(s, '{rows}', (select jsonb_agg(r) from jsonb_array_elements(s->'rows') r where r->>'label' not ilike 'Dimming interface%')) || '{"title":"Lighting — LED"}' else s end,
          case s->>'key' when 'fabric' then 0 when 'lighting' then 1 when 'shades' then 3 when 'control' then 4 when 'av' then 5 else 6 end
          from jsonb_array_elements(t.template->'sections') s
        union all select (select j from lc), 2) x))
where kind in ('media-room','cinema');
