
undefined4 __thiscall FUN_00435910(void *this,int param_1)

{
  bool bVar1;
  undefined3 extraout_var;
  void *this_00;
  int iVar2;
  byte *pbVar3;
  int iVar4;
  undefined3 extraout_var_00;
  undefined4 *puVar5;
  int iVar6;
  undefined4 *puVar7;
  undefined *puVar8;
  uint uVar9;
  int local_48;
  undefined4 local_44 [8];
  void *local_24;
  undefined *local_20;
  undefined4 local_8;
  
  if (*(int *)((int)this + 0x17c) == -1) {
    return 0;
  }
  bVar1 = FUN_00436310(this);
  if (CONCAT31(extraout_var,bVar1) == 0) {
    return 0;
  }
  this_00 = (void *)FUN_00433040(&DAT_004e3b18,*(int *)((int)this + 0x17c));
  if (*(float *)((int)this_00 + 0x38) != *(float *)((int)this_00 + 0x34)) {
    return 0;
  }
  FUN_0043cb00(DAT_004fe7ac,0x24,*(byte **)((int)this_00 + 0x50),(byte *)0x102);
  iVar2 = FUN_00432d40((int)this_00);
  FUN_00432bf0(this_00,-iVar2);
  pbVar3 = (byte *)FUN_00432d20((int)this_00);
  local_24 = this;
  switch(*(undefined4 *)((int)this_00 + 4)) {
  case 2:
    puVar8 = &DAT_004f1b10 + param_1 * 0x1e0;
    iVar2 = FUN_00435fe0(puVar8,1);
    if (iVar2 != 0) {
      return 1;
    }
    FUN_00436570(puVar8,3);
    FUN_00435f80(puVar8,6,pbVar3);
    FUN_00436570(this,1);
    local_20 = puVar8;
    FUN_0042ab30(&DAT_005090b0,0xab,(int *)&local_24);
    return 1;
  case 3:
    puVar8 = &DAT_004f1b10 + param_1 * 0x1e0;
    iVar2 = FUN_00435fe0(puVar8,1);
    if (iVar2 != 0) {
      return 1;
    }
    FUN_0043cb00(DAT_004fe7ac,0x3fe,
                 *(byte **)(*(int *)((&DAT_004f1b1c)[param_1 * 0x78] + 0x78) + 0xc),(byte *)0x0);
    FUN_00436570(puVar8,3);
    FUN_00435510(puVar8);
    FUN_00435f80(puVar8,3,pbVar3);
    uVar9 = 0xad;
    local_20 = puVar8;
    goto LAB_00435d5b;
  case 4:
    iVar2 = *(int *)(*(int *)((int)this + 0xc) + 0x78);
    iVar6 = FUN_0042bb50(iVar2);
    if ((iVar6 == 0) || (*(int *)(iVar6 + 0x30) == 0)) {
      return 0;
    }
    puVar5 = FUN_00427d70(1,0,0x40080000);
    puVar5[6] = 0;
    puVar5[7] = 0x3ff00000;
    puVar5[0x6d] = this;
    FUN_00427e90(puVar5,*(void **)(iVar2 + 0x28),*(int *)(iVar2 + 0x2c),-(int)pbVar3,0x3ed,this);
    FUN_00427f10((int)puVar5);
    uVar9 = 0xaf;
    goto LAB_00435d5b;
  case 5:
    FUN_00435f80(this,9,pbVar3);
    FUN_0042ab30(&DAT_005090b0,0xb1,(int *)&local_24);
    iVar2 = 2;
    break;
  case 6:
    iVar2 = *(int *)(*(int *)((int)this + 0xc) + 0x78);
    iVar6 = FUN_0042bb50(iVar2);
    if (iVar6 == 0) {
      return 0;
    }
    iVar4 = FUN_00435620((int)this);
    if (*(int *)(iVar6 + 0x34) == iVar4) {
      return 0;
    }
    if ((*(int *)(iVar6 + 0x30) != 0) && ((int)pbVar3 < *(int *)(*(int *)(iVar6 + 0x30) + 0x34))) {
      return 0;
    }
    FUN_0043cb00(DAT_004fe7ac,0x3ff,(byte *)((uint)(*(int *)(iVar2 + 0x28) - DAT_004e3844) / 0x58),
                 *(byte **)(iVar2 + 0x2c));
    pbVar3 = (byte *)FUN_00435620((int)this);
    FUN_0042b510(*(void **)(iVar2 + 0x28),*(uint *)(iVar2 + 0x2c),pbVar3);
    local_8 = *(undefined4 *)(iVar2 + 0x3c);
    FUN_0042ab30(&DAT_005090b0,0xb2,(int *)&local_24);
    iVar2 = 2;
    break;
  case 7:
    iVar2 = *(int *)(*(int *)((int)this + 0xc) + 0x78);
    iVar6 = FUN_0042bb50(iVar2);
    if (iVar6 == 0) {
      return 0;
    }
    if (*(int *)(iVar6 + 0x30) == 0) {
      return 0;
    }
    bVar1 = FUN_0041ce40(&DAT_004ece18,*(int *)(iVar6 + 0x30));
    if (CONCAT31(extraout_var_00,bVar1) == 0) {
      return 0;
    }
    puVar5 = FUN_00427d70(3,0,0x40080000);
    puVar5[6] = 0;
    puVar5[7] = 0x3ff00000;
    puVar5[0x6d] = this;
    FUN_00428250(puVar5,*(void **)(iVar2 + 0x28),*(int *)(iVar2 + 0x2c),(int)pbVar3,this);
    FUN_004282c0((int)puVar5);
    FUN_0042ab30(&DAT_005090b0,0xb3,(int *)&local_24);
    iVar2 = 2;
    break;
  case 8:
    FUN_00435f80(this,1,pbVar3);
    FUN_0042ab30(&DAT_005090b0,0xb5,(int *)&local_24);
    iVar2 = 2;
    break;
  case 9:
    iVar2 = FUN_0041f040(&DAT_004e48b8,0xf);
    (**(code **)(iVar2 + 0x21c))(0,0xf,this,param_1);
    return 1;
  case 10:
    FUN_0043cb00(DAT_004fe7ac,0x3fd,*(byte **)(*(int *)(*(int *)((int)this + 0xc) + 0x78) + 0xc),
                 (byte *)0x0);
    local_48 = FUN_0043a7d0((int)local_44,(float *)0x0,6,
                            *(void **)(*(int *)((int)this + 0xc) + 0x78),(int)this);
    if (0 < local_48) {
      puVar5 = local_44;
      do {
        iVar2 = FUN_00435fe0((void *)*puVar5,1);
        if (((iVar2 == 0) && (iVar2 = FUN_00435630((void *)*puVar5,0xff), iVar2 != -1)) &&
           (iVar6 = FUN_00433040(&DAT_004e3b18,iVar2), *(int *)(iVar6 + 4) != 10)) {
          puVar7 = (undefined4 *)FUN_00433040(&DAT_004e3b18,iVar2);
          FUN_00432c20(puVar7);
        }
        puVar5 = puVar5 + 1;
        local_48 = local_48 + -1;
      } while (local_48 != 0);
    }
    uVar9 = 0xb7;
LAB_00435d5b:
    FUN_0042ab30(&DAT_005090b0,uVar9,(int *)&local_24);
    iVar2 = 1;
    break;
  default:
    goto switchD_004359b2_default;
  }
  FUN_00436570(this,iVar2);
switchD_004359b2_default:
  return 1;
}

