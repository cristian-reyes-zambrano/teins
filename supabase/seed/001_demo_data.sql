-- ═══════════════════════════════════════════════════════════════════════════
-- TEINS App — Datos de demostración
-- Versión: 001
--
-- IMPORTANTE: Ejecutar DESPUÉS de las migraciones 001-004.
-- Este seed crea datos para desarrollo y pruebas.
-- NO ejecutar en producción.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── UUIDs fijos para datos de demo (facilitan pruebas reproducibles) ──────────

-- Usuario técnico demo (crear primero en Supabase Auth, luego el perfil)
-- Email: tecnico@teins.com / Password: Teins2025!
-- Ejecutar en Supabase Auth o usar la API de admin para crear el usuario.

DO $$
DECLARE
    v_tech_id        UUID := 'a9c8bb91-26b0-4169-9495-13bb569929cf';
    v_office_id      UUID := '30d254c7-0b1e-433b-ace6-421bb011d2da';
    v_template_infra UUID := '10000000-0000-4000-8000-000000000001';
    v_template_energ UUID := '10000000-0000-4000-8000-000000000002';
    v_template_datos UUID := '10000000-0000-4000-8000-000000000003';
    v_visit_1        UUID := '20000000-0000-4000-8000-000000000001';
    v_visit_2        UUID := '20000000-0000-4000-8000-000000000002';
    v_visit_3        UUID := '20000000-0000-4000-8000-000000000003';
BEGIN

-- ── Tipos de visita ──────────────────────────────────────────────────────────

    INSERT INTO visit_types (id, name, description, icon, is_active)
    VALUES
        (gen_random_uuid(), 'Infraestructura', 'Visitas de inspección de infraestructura física', 'construction', TRUE),
        (gen_random_uuid(), 'Energía', 'Visitas de inspección y mantenimiento eléctrico', 'bolt', TRUE),
        (gen_random_uuid(), 'Datos', 'Visitas de instalación y soporte de redes de datos', 'cable', TRUE)
    ON CONFLICT DO NOTHING;

-- ── Perfiles demo ─────────────────────────────────────────────────────────────
-- Nota: Los UUIDs deben coincidir con usuarios creados en auth.users

    INSERT INTO profiles (id, email, full_name, role, phone, is_active)
    VALUES
        (v_tech_id,   'tecnico@teins.com',  'Carlos Técnico Demo', 'technician', '+1-555-0101', TRUE),
        (v_office_id, 'oficina@teins.com',  'Ana Oficina Demo',    'office',     '+1-555-0102', TRUE)
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        updated_at = NOW();

-- ── Plantillas de formularios ─────────────────────────────────────────────────

    INSERT INTO form_templates (id, name, visit_type, version, sections_json, is_active)
    VALUES (
        v_template_infra,
        'Inspección de Infraestructura',
        'infraestructura',
        1,
        '[
          {
            "id": "general",
            "title": "Información General",
            "order": 0,
            "fields": [
              {"id":"ubicacion","type":"text","label":"Ubicación exacta","required":true,"hint":"Descripción detallada del sitio"},
              {"id":"descripcion","type":"textarea","label":"Descripción general","required":true},
              {"id":"acceso","type":"select","label":"Tipo de acceso","required":true,"options":["Libre","Controlado","Restringido","Con escolta"]},
              {"id":"condicion_sitio","type":"select","label":"Condición del sitio","required":true,"options":["Excelente","Bueno","Regular","Deficiente","Crítico"]}
            ]
          },
          {
            "id": "medidas",
            "title": "Medidas y Dimensiones",
            "order": 1,
            "fields": [
              {"id":"largo","type":"decimal","label":"Largo (m)","required":false,"unit":"m"},
              {"id":"ancho","type":"decimal","label":"Ancho (m)","required":false,"unit":"m"},
              {"id":"alto","type":"decimal","label":"Alto (m)","required":false,"unit":"m"}
            ]
          },
          {
            "id": "observaciones",
            "title": "Observaciones",
            "order": 2,
            "fields": [
              {"id":"observaciones_generales","type":"textarea","label":"Observaciones generales","required":false},
              {"id":"requiere_intervencion","type":"boolean","label":"¿Requiere intervención inmediata?","required":true},
              {"id":"prioridad","type":"select","label":"Prioridad","required":false,"options":["Baja","Media","Alta","Urgente"]}
            ]
          }
        ]'::jsonb,
        TRUE
    ),
    (
        v_template_energ,
        'Inspección de Energía',
        'energia',
        1,
        '[
          {
            "id": "instalacion",
            "title": "Datos de la Instalación",
            "order": 0,
            "fields": [
              {"id":"tipo_instalacion","type":"select","label":"Tipo de instalación","required":true,"options":["Residencial","Comercial","Industrial","Corporativa"]},
              {"id":"voltaje_entrada","type":"decimal","label":"Voltaje de entrada (V)","required":true,"unit":"V"},
              {"id":"corriente_nominal","type":"decimal","label":"Corriente nominal (A)","required":false,"unit":"A"},
              {"id":"fases","type":"select","label":"Número de fases","required":true,"options":["Monofásico","Bifásico","Trifásico"]}
            ]
          },
          {
            "id": "estado",
            "title": "Estado del Sistema",
            "order": 1,
            "fields": [
              {"id":"estado_tablero","type":"select","label":"Estado del tablero eléctrico","required":true,"options":["Bueno","Regular","Deficiente","Requiere reemplazo"]},
              {"id":"tiene_tierra","type":"boolean","label":"¿Tiene puesta a tierra?","required":true},
              {"id":"tiene_protecciones","type":"boolean","label":"¿Tiene protecciones?","required":true},
              {"id":"tipo_cable","type":"select","label":"Tipo de cable predominante","required":false,"options":["Thhn","Thw","NMB","Concéntrico","Otro"]}
            ]
          },
          {
            "id": "observaciones",
            "title": "Observaciones",
            "order": 2,
            "fields": [
              {"id":"anomalias","type":"textarea","label":"Anomalías detectadas","required":false},
              {"id":"requiere_intervencion","type":"boolean","label":"¿Requiere intervención?","required":true}
            ]
          }
        ]'::jsonb,
        TRUE
    ),
    (
        v_template_datos,
        'Inspección de Datos / Red',
        'datos',
        1,
        '[
          {
            "id": "red",
            "title": "Datos de la Red",
            "order": 0,
            "fields": [
              {"id":"tipo_red","type":"select","label":"Tipo de red","required":true,"options":["LAN","WAN","Fibra óptica","Inalámbrica","Híbrida"]},
              {"id":"tipo_cableado","type":"select","label":"Tipo de cableado","required":true,"options":["Cat5e","Cat6","Cat6A","Cat7","Fibra OS1","Fibra OS2"]},
              {"id":"longitud_total","type":"decimal","label":"Longitud total de cableado (m)","required":false,"unit":"m"},
              {"id":"cantidad_puntos","type":"number","label":"Cantidad de puntos de red","required":false}
            ]
          },
          {
            "id": "conectividad",
            "title": "Conectividad",
            "order": 1,
            "fields": [
              {"id":"velocidad_bajada","type":"decimal","label":"Velocidad real bajada (Mbps)","required":false,"unit":"Mbps"},
              {"id":"velocidad_subida","type":"decimal","label":"Velocidad real subida (Mbps)","required":false,"unit":"Mbps"},
              {"id":"latencia","type":"decimal","label":"Latencia (ms)","required":false,"unit":"ms"},
              {"id":"proveedor","type":"text","label":"Proveedor de internet","required":false}
            ]
          },
          {
            "id": "observaciones",
            "title": "Observaciones",
            "order": 2,
            "fields": [
              {"id":"problemas_detectados","type":"textarea","label":"Problemas detectados","required":false},
              {"id":"requiere_intervencion","type":"boolean","label":"¿Requiere intervención?","required":true}
            ]
          }
        ]'::jsonb,
        TRUE
    )
    ON CONFLICT (id) DO NOTHING;

-- ── Catálogo de materiales demo ───────────────────────────────────────────────

    INSERT INTO material_catalog (id, code, name, description, unit, category, is_active) VALUES
        (gen_random_uuid(), 'CABLE-UTP-CAT6',   'Cable UTP Cat6',               'Cable de red UTP categoría 6, 23 AWG',             'metro',  'Cableado',        TRUE),
        (gen_random_uuid(), 'CABLE-THHN-12',    'Cable THHN #12 AWG',           'Cable eléctrico THHN calibre 12',                  'metro',  'Cableado',        TRUE),
        (gen_random_uuid(), 'CABLE-THHN-10',    'Cable THHN #10 AWG',           'Cable eléctrico THHN calibre 10',                  'metro',  'Cableado',        TRUE),
        (gen_random_uuid(), 'FIBRA-SM-OS2',     'Fibra óptica OS2 monomodo',    'Fibra óptica monomodo OS2 para exteriores',        'metro',  'Cableado',        TRUE),
        (gen_random_uuid(), 'CONEC-RJ45-CAT6',  'Conector RJ45 Cat6',           'Conector macho RJ45 para cable Cat6',              'unidad', 'Conectores',      TRUE),
        (gen_random_uuid(), 'CONEC-LC-SM',      'Conector LC monomodo',         'Conector LC/UPC para fibra monomodo',              'unidad', 'Conectores',      TRUE),
        (gen_random_uuid(), 'TUBO-EMT-3/4',     'Tubería EMT 3/4"',             'Tubería metálica EMT para instalaciones eléctricas','metro', 'Tubería',         TRUE),
        (gen_random_uuid(), 'CANALETA-40X25',   'Canaleta 40×25 mm',            'Canaleta plástica para cable de red 40×25mm',      'metro',  'Tubería',         TRUE),
        (gen_random_uuid(), 'BREAKER-1P-20A',   'Breaker 1P 20A',               'Interruptor termomagnético 1 polo 20 amperios',    'unidad', 'Protecciones',    TRUE),
        (gen_random_uuid(), 'BREAKER-2P-30A',   'Breaker 2P 30A',               'Interruptor termomagnético 2 polos 30 amperios',   'unidad', 'Protecciones',    TRUE),
        (gen_random_uuid(), 'PATCH-PANEL-24',   'Patch panel 24 puertos Cat6',  'Panel de parcheo 24 puertos Cat6 1U',              'unidad', 'Equipos de red',  TRUE),
        (gen_random_uuid(), 'KEYSTONE-CAT6',    'Keystone Jack Cat6',           'Módulo keystone hembra Cat6',                      'unidad', 'Equipos de red',  TRUE),
        (gen_random_uuid(), 'ABRAZA-3/4',       'Abrazadera 3/4"',              'Abrazadera metálica para tubería 3/4"',            'unidad', 'Fijación',        TRUE),
        (gen_random_uuid(), 'BRIDA-NEGRO',      'Brida nylon 300mm',            'Brida de amarre de nylon negra 300mm',             'unidad', 'Fijación',        TRUE)
    ON CONFLICT (code) DO NOTHING;

-- ── Visitas demo ──────────────────────────────────────────────────────────────

    INSERT INTO visits (
        id, technician_id, title, visit_type,
        address, status, sync_status,
        form_template_id, form_template_version,
        client_name, description, created_at
    ) VALUES
        (
            v_visit_1, v_tech_id,
            'VT-00001 — Inspección Infraestructura Almacén Sur',
            'infraestructura',
            'Calle Industrial 123, Zona Sur, Loja',
            'assigned', 'synced',
            v_template_infra, 1,
            'Almacenes ABC S.A.',
            'Revisión completa de infraestructura del almacén zona sur.',
            NOW() - INTERVAL '2 days'
        ),
        (
            v_visit_2, v_tech_id,
            'VT-00002 — Inspección Energía Planta Norte',
            'energia',
            'Av. Industrial Norte 456, Parque Industrial',
            'inProgress', 'pendingSync',
            v_template_energ, 1,
            'Industrias XYZ Ltda.',
            'Inspección del sistema eléctrico planta de producción.',
            NOW() - INTERVAL '1 day'
        ),
        (
            v_visit_3, v_tech_id,
            'VT-00003 — Instalación Red Datos Oficinas Centrales',
            'datos',
            'Torre Empresarial, Piso 8, Centro',
            'assigned', 'synced',
            v_template_datos, 1,
            'Corporación DEF',
            'Instalación y certificación de red Cat6 en 3 pisos.',
            NOW() - INTERVAL '3 hours'
        )
    ON CONFLICT (id) DO NOTHING;

    RAISE NOTICE 'Seed data cargado correctamente.';
    RAISE NOTICE '─────────────────────────────────────────';
    RAISE NOTICE 'Usuarios demo:';
    RAISE NOTICE '  Técnico:  tecnico@teins.com  / Teins2025!';
    RAISE NOTICE '  Oficina:  oficina@teins.com  / Teins2025!';
    RAISE NOTICE '─────────────────────────────────────────';
    RAISE NOTICE 'Visitas creadas: VT-00001, VT-00002, VT-00003';

END;
$$;
