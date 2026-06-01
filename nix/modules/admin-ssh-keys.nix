_: let
  keys = map (file: builtins.readFile "${../public_keys}/${file}") (builtins.attrNames (builtins.readDir ../public_keys));
in {
  users.users.admin.openssh.authorizedKeys.keys = keys;
}
