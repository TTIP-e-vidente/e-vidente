-- Configuracion de nodos por restriccion.
-- total_nodes es la cantidad de nodos que define el mapa del juego (fuente: JSON de Godot).
-- Cuando se agrega o modifica un mapa, crear una nueva migracion que actualice esta tabla.
-- CELIAQUIA: 30 nodos (celiaquia_mapa.json, claves celiaquia_01 .. celiaquia_30)

CREATE TABLE IF NOT EXISTS restriction_node_config (
  restriction   VARCHAR(50)  PRIMARY KEY,
  total_nodes   INTEGER      NOT NULL CHECK (total_nodes > 0),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO restriction_node_config (restriction, total_nodes)
VALUES
  ('CELIAQUIA', 30)
ON CONFLICT (restriction) DO UPDATE
  SET total_nodes = EXCLUDED.total_nodes,
      updated_at  = now();
