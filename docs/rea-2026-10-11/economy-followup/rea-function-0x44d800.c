
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __fastcall FUN_0044d7d0(int param_1)

{
  char cVar1;
  
  *(undefined4 *)(param_1 + 0x120) = _DAT_004e37c0;
  *(undefined4 *)(param_1 + 0x124) = DAT_004e37c4;
  *(undefined4 *)(param_1 + 0x128) = DAT_004e37c8;
  cVar1 = (&DAT_004e37c0)[*(int *)(param_1 + 0xec)];
  if (-1 < cVar1) {
    *(undefined **)(param_1 + 0x110) = &DAT_004e1b80 + cVar1 * 0x1e0;
    if (&DAT_004e1b80 + cVar1 * 0x1e0 == &DAT_004e1b80 + DAT_004e2a84 * 0x1e0) {
      FUN_00423ec0(DAT_004fe7b0,0x69,*(char **)(param_1 + 0x114),0);
    }
    FUN_00429cd0(0x4e2aa8);
    return;
  }
  return;
}

