
undefined4 FUN_00447d20(void)

{
  bool bVar1;
  undefined3 extraout_var;
  int iVar2;
  int iVar3;
  undefined4 uVar4;
  undefined *this;
  
  iVar3 = DAT_004e2a84;
  this = &DAT_004e1b80 + DAT_004e2a84 * 0x1e0;
  bVar1 = FUN_00436520(this);
  if (CONCAT31(extraout_var,bVar1) != 0) {
    iVar2 = FUN_0045a8f0(DAT_00500178);
    if (iVar2 != 0) {
      FUN_0042bb50(*(int *)((&DAT_004e1b8c)[iVar3 * 0x78] + 0x78));
      iVar3 = FUN_00435630(this,0xff);
      if (-1 < iVar3) {
        iVar3 = FUN_00433040(&DAT_004c7048,iVar3);
        if (*(float *)(iVar3 + 0x38) == *(float *)(iVar3 + 0x34)) {
          uVar4 = FUN_00435820(this,*(int *)(iVar3 + 4),*(int *)(iVar3 + 0x30));
          return uVar4;
        }
      }
    }
  }
  return 0;
}

