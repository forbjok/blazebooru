CREATE TABLE refresh_token
(
  id bigserial NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,

  token uuid NOT NULL DEFAULT gen_random_uuid(),
  session bigint NOT NULL,
  user_id integer NOT NULL,
  created_ip inet NOT NULL,
  expires_at timestamp with time zone NOT NULL DEFAULT (CURRENT_TIMESTAMP + '30 days'::interval),

  used boolean NOT NULL DEFAULT false,
  used_ip inet,

  PRIMARY KEY (id),
  UNIQUE (token)
);

SELECT manage_updated_at('refresh_token'); -- Automatically manage updated_at
