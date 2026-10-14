
void __fastcall FUN_00441020(void *param_1)

{
  bool bVar1;
  int iVar2;
  int *piVar3;
  void *pvVar4;
  undefined3 extraout_var;
  void *pvVar5;
  int iVar6;
  
  iVar2 = FUN_00441430((int)param_1);
  if (iVar2 != 1) {
    if ((DAT_004f2e18 == 0) || (*(double *)((int)param_1 + 0x20) < (double)(DAT_004f2e18 * 0x3c))) {
      iVar2 = 0;
      if (0 < *(int *)((int)param_1 + 8)) {
        iVar6 = 0;
        do {
          if ((*(int *)(*(int *)((int)param_1 + 4) + 0x40 + iVar6) != 0) &&
             (bVar1 = FUN_004409e0(*(int *)((int)param_1 + 4) + iVar6),
             CONCAT31(extraout_var,bVar1) != 0)) {
            FUN_004409f0((void *)(*(int *)((int)param_1 + 4) + iVar6));
          }
          iVar2 = iVar2 + 1;
          iVar6 = iVar6 + 0x3a8;
        } while (iVar2 < *(int *)((int)param_1 + 8));
      }
    }
    else {
      if (DAT_004f2a30 == 0) {
        pvVar4 = (void *)FUN_00441810(param_1,2,(void *)0x0);
      }
      else {
        piVar3 = FUN_0043a940(0x4f1b08);
        pvVar4 = (void *)FUN_00435620((int)piVar3);
      }
      FUN_00436570(*(void **)((int)pvVar4 + 0x2e0),7);
      iVar2 = 0;
      if (0 < *(int *)((int)param_1 + 0xc)) {
        iVar6 = 0;
        do {
          pvVar5 = (void *)(*(int *)((int)param_1 + 4) + iVar6);
          if ((*(int *)(*(int *)((int)param_1 + 4) + 0x40 + iVar6) != 0) && (pvVar5 != pvVar4)) {
            FUN_004409f0(pvVar5);
          }
          iVar2 = iVar2 + 1;
          iVar6 = iVar6 + 0x3a8;
        } while (iVar2 < *(int *)((int)param_1 + 0xc));
      }
    }
    iVar2 = FUN_00441140((int)param_1);
    if (iVar2 != 0) {
      FUN_00436570(*(void **)(iVar2 + 0x2e0),7);
      FUN_0043c5e0(DAT_004fe7ac,0x898,(uint *)0x0,*(int *)(iVar2 + 0x2e0));
    }
  }
  return;
}

