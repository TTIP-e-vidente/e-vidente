-- Restricciones sin mapa implementado aún usan total_nodes = 9999 como centinela
-- para que map_completed nunca dispare hasta que se actualice con el valor real.
-- Cuando un mapa esté listo, crear una nueva migración con el total_nodes correcto.

INSERT INTO restriction_node_config (restriction, total_nodes)
VALUES
  ('VEG',  9999),
  ('VYG',  9999),
  ('KETO', 9999)
ON CONFLICT (restriction) DO NOTHING;
