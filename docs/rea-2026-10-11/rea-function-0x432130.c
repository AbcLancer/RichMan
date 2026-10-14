
void __fastcall FUN_00432130(int param_1)

{
  int iVar1;
  byte local_64 [2];
  undefined4 local_62;
  
  local_64[1] = *(byte *)(param_1 + 0x40);
  if (local_64[1] != 0) {
    iVar1 = 2;
    if ((local_64[1] & 1) != 0) {
      local_62 = *(undefined4 *)(param_1 + 0x38);
      iVar1 = 6;
    }
    if ((local_64[1] & 2) != 0) {
      local_64[iVar1] = *(byte *)(param_1 + 0x30);
      iVar1 = iVar1 + 1;
    }
    if ((local_64[1] & 4) != 0) {
      *(undefined4 *)(local_64 + iVar1) = *(undefined4 *)(param_1 + 0x34);
      iVar1 = iVar1 + 4;
    }
    if ((local_64[1] & 8) != 0) {
      local_64[iVar1] = *(byte *)(param_1 + 4);
      iVar1 = iVar1 + 1;
    }
    local_64[0] = (char)iVar1 - 1;
    FUN_0043cb00(DAT_004fe7ac,0x21,local_64,*(byte **)(param_1 + 0x50));
    *(undefined1 *)(param_1 + 0x40) = 0;
  }
  return;
}

