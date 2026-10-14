
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

undefined4 FUN_00438ab0(int *param_1,int param_2)

{
  void *this;
  int *piVar1;
  bool bVar2;
  int iVar3;
  int iVar4;
  undefined3 extraout_var;
  byte *pbVar5;
  int iVar6;
  undefined3 extraout_var_00;
  undefined3 extraout_var_01;
  uint *puVar7;
  byte *pbVar8;
  
  piVar1 = param_1;
  this = *(void **)(param_2 + 0x28);
  iVar3 = FUN_0042bb50(param_2);
  if (iVar3 == 0) {
    return 1;
  }
  if ((*(byte *)(iVar3 + 0xc) & 2) == 0) {
    return 1;
  }
  if (*(int *)(iVar3 + 0x34) != param_1[0x70]) {
    if (*(int *)(iVar3 + 0x34) != 0) {
      return 0;
    }
    if (param_1[0xd] != 3) {
      FUN_00434280(param_1,6,*(undefined4 *)((int)DAT_004fe7ac + 0x8008));
      puVar7 = (uint *)FUN_0042b450(*(void **)(param_2 + 0x28),*(int *)(param_2 + 0x2c),0.0);
      iVar3 = FUN_00435620((int)param_1);
      if (*(int *)(iVar3 + 0x4c) < (int)puVar7) {
        _DAT_004fdb20 = param_1;
        FUN_0042ab30(&DAT_005090b0,0x58,(int *)&DAT_004fdb20);
        return 0;
      }
      FUN_0043c5e0(DAT_004fe7ac,0xc9,puVar7,(int)param_1);
      return 0;
    }
    bVar2 = FUN_0041e0c0(iVar3,param_2,(int)param_1);
    if (CONCAT31(extraout_var_01,bVar2) == 0) {
      return 1;
    }
    FUN_00439bf0((undefined4 *)0x5,(byte *)param_2,(byte *)param_1);
    return 1;
  }
  iVar4 = FUN_00435fe0(param_1,7);
  if ((iVar4 != 0) &&
     (bVar2 = FUN_0041ce40(&DAT_004ece18,*(int *)(iVar3 + 0x30)), CONCAT31(extraout_var,bVar2) != 0)
     ) {
    FUN_0041e110(this,*(uint *)(iVar3 + 0x14),1);
    _DAT_004fdb20 = param_1;
    FUN_0042ab30(&DAT_005090b0,0x41a,(int *)&DAT_004fdb20);
  }
  pbVar5 = (byte *)FUN_0041dd60(0x4ece18);
  *(void **)(pbVar5 + 0x1d4) = this;
  *(int **)(pbVar5 + 0x1d0) = param_1;
  iVar4 = 1;
  pbVar8 = pbVar5 + 0x28;
  param_1 = (int *)(pbVar5 + 0x128);
  do {
    iVar6 = FUN_0041d5e0(this,*(int *)(param_2 + 0x2c),iVar4,(int)piVar1,(int)pbVar8,
                         (int)(pbVar8 + 0x90));
    *param_1 = iVar6;
    iVar4 = iVar4 + 1;
    param_1 = param_1 + 1;
    pbVar8 = pbVar8 + 0x24;
  } while (iVar4 < 4);
  bVar2 = FUN_0041ce40(&DAT_004ece18,*(int *)(iVar3 + 0x30));
  if (CONCAT31(extraout_var_00,bVar2) == 0) {
    iVar4 = FUN_0041ddd0((int)pbVar5);
    if (iVar4 != 0) goto LAB_00438c16;
  }
  else {
    iVar4 = *(int *)(*(int *)(iVar3 + 0x30) + 0x34);
    pbVar8 = pbVar5 + iVar4 * 4 + 0x124;
    pbVar8[0] = 1;
    pbVar8[1] = 0;
    pbVar8[2] = 0;
    pbVar8[3] = 0;
    *(int *)(pbVar5 + 0x124) = iVar4;
    *(int *)(pbVar5 + iVar4 * 0x24 + 4) = *(int *)(iVar3 + 0x14) % *(int *)((int)this + 0x4c);
    *(int *)(pbVar5 + iVar4 * 0x24 + 0x94) = *(int *)(iVar3 + 0x14) / *(int *)((int)this + 0x4c);
  }
  if (piVar1[0xd] == 3) {
    iVar3 = FUN_0041de00(&DAT_004ece18,(int *)pbVar5,iVar3);
    if (iVar3 == 0) {
      FUN_0041ddc0((undefined4 *)pbVar5);
      return 0;
    }
    FUN_00439bf0((undefined4 *)0x6,pbVar5,(byte *)piVar1);
  }
  else {
    iVar3 = FUN_0041dca0(&DAT_004ece18,*(int *)(iVar3 + 0x30),(int)pbVar5,piVar1);
    if (iVar3 != 0) {
      return 0;
    }
  }
LAB_00438c16:
  FUN_0041ddc0((undefined4 *)pbVar5);
  return 1;
}

