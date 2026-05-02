let
  server = "age1rh8v46hcxj9jcl0nqruw9fny75dd0xlqgakychjh477atnvwwswslu3nd6";
  host   = "age195kkgkst85dahhg0hlunfw2g8v8dqpma2eggtvn2cnrrvwy8hcgqnp5z56";
  all    = [ server host ];
in
{
  "convertx-jwt-secret.age".publicKeys      = all;
  "gitea-secret-key.age".publicKeys         = all;
  "paperless-admin-password.age".publicKeys = all;
  "paperless-secret-key.age".publicKeys     = all;
  "send-secret.age".publicKeys              = all;
  "traefik-tls-cert.age".publicKeys         = all;
  "traefik-tls-key.age".publicKeys          = all;
  "vaultwarden-admin-token.age".publicKeys  = all;
}
