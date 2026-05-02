let
  server = "age1wwy6kl3utq66tghq34aq30vxmtrqq0kfa505yf2n9kryn89s8dyqvy5u3j";
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
