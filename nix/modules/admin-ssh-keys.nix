{...}: let
  isRootKey = file: builtins.match "root_.*" file != null;
  isUserKey = file: !isRootKey file;
  userSshPublicKeys =
    map
    (file: builtins.readFile "${../publicKeys}/${file}")
    (builtins.filter isUserKey (builtins.attrNames (builtins.readDir ../publicKeys)));
in {
  users.users.admin.openssh.authorizedKeys.keys = userSshPublicKeys;
}
