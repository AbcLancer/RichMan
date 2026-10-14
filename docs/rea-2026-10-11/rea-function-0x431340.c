
bool __cdecl FUN_00431340(void *param_1)

{
  int iVar1;
  
  FUN_0043cb00(DAT_004fe7ac,0x3ec,*(byte **)(*(int *)(*(int *)((int)param_1 + 0xc) + 0x78) + 0xc),
               (byte *)0xa);
  iVar1 = FUN_00435fe0(param_1,1);
  if (iVar1 == 0) {
    iVar1 = FUN_00435fe0(param_1,0xb);
    if (iVar1 == 0) {
      FUN_0043cb00(DAT_004fe7ac,0x403,*(byte **)((int)param_1 + 0x38),(byte *)0x0);
      FUN_00436810(param_1,0x16,0);
      FUN_00434350(param_1,-DAT_00508f28);
      FUN_0042f9b0((byte *)0x24,*(void **)(*(int *)((int)param_1 + 0xc) + 0x78));
      return *(int *)((int)param_1 + 0x3c) == 2;
    }
  }
  return false;
}

