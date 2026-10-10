let
  publicKeys = map (file: builtins.readFile (../public_keys + "/${file}")) (builtins.attrNames (builtins.readDir ../public_keys));
in {
  "ntfy-admin.age" = {
    inherit publicKeys;
    armor = true;
  };
}
