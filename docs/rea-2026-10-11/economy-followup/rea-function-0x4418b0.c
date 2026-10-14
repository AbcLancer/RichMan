
int __fastcall FUN_004418b0(void *param_1)

{
  void *pvVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  
  iVar3 = 0;
  iVar2 = 0;
  iVar4 = 0;
  if (0 < *(int *)((int)param_1 + 0xc)) {
    do {
      pvVar1 = (void *)FUN_00441000(param_1,iVar4);
      if (*(int *)((int)pvVar1 + 0x40) != 0) {
        pvVar1 = FUN_0043f270(pvVar1);
        iVar3 = iVar3 + (int)pvVar1;
        iVar2 = iVar2 + 1;
      }
      iVar4 = iVar4 + 1;
    } while (iVar4 < *(int *)((int)param_1 + 0xc));
    if (0 < iVar2) {
      return iVar3 / iVar2;
    }
  }
  return 1;
}

