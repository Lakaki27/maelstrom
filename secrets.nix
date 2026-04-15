let
  server = "age1cdcj8ce4qqd3793c3k0lf7k0sjv8fnrv42su8uh2lq8dkaueusjqsy5xx3";
  host   = "age195kkgkst85dahhg0hlunfw2g8v8dqpma2eggtvn2cnrrvwy8hcgqnp5z56";
  all    = [ server host ];
in
{
  "chiyogami-secret-key.age".publicKeys           = all;
  "convertx-jwt-secret.age".publicKeys           = all;
  "gitea-secret-key.age".publicKeys           = all;
  "paperless-admin-password.age".publicKeys           = all;
  "paperless-secret-key.age".publicKeys           = all;
  "send-secret.age".publicKeys           = all;
  "traefik-tls-cert.age".publicKeys           = all;
  "traefik-tls-key.age".publicKeys           = all;
  "vaultwarden-admin-token.age".publicKeys           = all;
}
