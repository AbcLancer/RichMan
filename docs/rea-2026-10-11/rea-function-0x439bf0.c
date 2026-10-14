
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void FUN_00439bf0(undefined4 *param_1,byte *param_2,byte *param_3)

{
  byte *this;
  uint uVar1;
  byte *pbVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  byte *pbVar6;
  
  this = param_3;
  uVar1 = (int)param_1 - 1;
  pbVar6 = param_2;
  if (99 < uVar1) {
switchD_00439c14_caseD_4:
    return;
  }
LAB_00439c0c:
                    /* WARNING: Could not find normalized switch variable to match jumptable */
  switch((&switchD_00439c14::switchdataD_0043a078)[uVar1]) {
  case 1:
    FUN_0043cb00(DAT_004fe7ac,0x1f7,(byte *)0x0,pbVar6);
    iVar3 = *(int *)(*(int *)(pbVar6 + 0xc) + 0x78);
    if (*(char *)(iVar3 + 0x30) == '\0') {
      return;
    }
    iVar4 = FUN_004363d0(pbVar6);
    if (iVar4 == 0) {
      return;
    }
    if (*(int *)(*(int *)(pbVar6 + 0xc) + 0x88) < 1) {
      return;
    }
    FUN_00439530(*(uint *)(iVar3 + 0x30) & 0xff,pbVar6,1);
    return;
  case 2:
    FUN_00439160((int *)pbVar6,this,(uint)(*(int *)(pbVar6 + 0x3c) == 4));
    return;
  case 3:
    if ((*(int *)(*(int *)(this + 0xc) + 0x98) != 0) &&
       (iVar3 = FUN_00436230(this,*(int *)(this + 0x3c)), iVar3 != 0)) {
      FUN_00435510(this);
      FUN_00423250(*(void **)(this + 0xc),(int)pbVar6);
      FUN_0043cb00(DAT_004fe7ac,0x1f7,(byte *)0x0,this);
      return;
    }
    FUN_0043c5e0(DAT_004fe7ac,2,(uint *)0x0,(int)this);
    return;
  default:
    goto switchD_00439c14_caseD_4;
  case 5:
    iVar3 = FUN_00435fe0(this,8);
    if (iVar3 != 0) {
      _DAT_004fdb20 = this;
      FUN_0042ab30(&DAT_005090b0,0x41d,(int *)&DAT_004fdb20);
      return;
    }
    FUN_0042bb50((int)pbVar6);
    pbVar2 = (byte *)FUN_0042b450(*(void **)(pbVar6 + 0x28),*(int *)(pbVar6 + 0x2c),0.0);
    if ((int)pbVar2 <= *(int *)(*(int *)(this + 0x1c0) + 0x4c)) {
      FUN_0041a9d0(&DAT_004e3b28,1,(float)pbVar2);
      FUN_0043ff30(*(void **)(this + 0x1c0),pbVar2,1);
      FUN_0042b510(*(void **)(pbVar6 + 0x28),*(uint *)(pbVar6 + 0x2c),*(byte **)(this + 0x1c0));
      FUN_0042f9b0((byte *)0xb,pbVar6);
      _DAT_004fdb20 = this;
      _DAT_004fdb24 = this;
      DAT_004fdb3c = *(undefined4 *)(pbVar6 + 0x3c);
      FUN_0042ab30(&DAT_005090b0,0x51,(int *)&DAT_004fdb20);
      iVar3 = FUN_00405130(1,6);
      if (iVar3 != 1) {
        return;
      }
      FUN_00436570(this,0xd);
      return;
    }
    break;
  case 6:
    iVar3 = *(int *)(pbVar6 + 0x1c4) * 3 + *(int *)(pbVar6 + 0x1c8);
    iVar3 = FUN_0041ce10(&DAT_004ece18,*(int *)(pbVar6 + iVar3 * 4 + 0x134),*(int *)(pbVar6 + 0x1c4)
                         ,*(int *)(pbVar6 + iVar3 * 4 + 0x164));
    iVar4 = *(int *)(pbVar6 + 0x1c4) * 9 + *(int *)(pbVar6 + 0x1cc);
    iVar5 = *(int *)(pbVar6 + iVar4 * 4 + 0x94) * *(int *)((int)*(void **)(pbVar6 + 0x1d4) + 0x4c) +
            *(int *)(pbVar6 + iVar4 * 4 + 4);
    param_1 = (undefined4 *)FUN_0041cec0(*(void **)(pbVar6 + 0x1d4),iVar5,*(int *)(iVar3 + 0x34));
    iVar4 = FUN_00435620((int)this);
    if (*(int *)(iVar3 + 0x3c) <= *(int *)(iVar4 + 0x4c)) {
      FUN_0041cf40(*(void **)(pbVar6 + 0x1d4),iVar5,iVar3,*(int *)(this + 0x1c0),(char)param_1);
      FUN_0041d9e0(*(void **)(pbVar6 + 0x1d4),0);
      FUN_0041a9d0(&DAT_004e3b28,1,*(float *)(iVar3 + 0x3c));
      FUN_0043ff30(*(void **)(this + 0x1c0),*(byte **)(iVar3 + 0x3c),1);
      _DAT_004fdb20 = this;
      _DAT_004fdb24 = this;
      DAT_004fdb3c = *(undefined4 *)(*(int *)(*(int *)(this + 0xc) + 0x78) + 0x3c);
      FUN_0042ab30(&DAT_005090b0,0x52,(int *)&DAT_004fdb20);
      iVar3 = FUN_00405130(1,6);
      if (iVar3 != 1) {
        return;
      }
      FUN_00436570(this,0xd);
      return;
    }
    break;
  case 0x16:
    goto switchD_00439c14_caseD_16;
  case 100:
    FUN_00434260(this,&param_1);
    iVar3 = FUN_00435fe0(this,8);
    if (iVar3 != 0) {
      FUN_0041ddc0(param_1);
      _DAT_004fdb20 = this;
      FUN_0042ab30(&DAT_005090b0,0x41d,(int *)&DAT_004fdb20);
      return;
    }
    param_1[0x71] = (uint)pbVar6 / 3 + 1;
    iVar4 = param_1[0x71];
    iVar3 = (uint)pbVar6 % 3 + iVar4 * 3;
    param_1[0x72] = (uint)pbVar6 % 3;
    if ((param_1[iVar3 + 0x4d] == -1) || ((int)param_1[iVar3 + 0x59] < 1)) {
      FUN_00401050((byte *)s_buildtype__type__d_size__d_0049eb10);
      FUN_00401050((byte *)s_buildinfo___d___d_0049eafc);
    }
    iVar3 = param_1[iVar4 + 0x49];
    param_1[0x73] = 0;
    if (iVar3 == 1) {
      FUN_00439bf0((undefined4 *)0x6,(byte *)param_1,this);
      FUN_0041ddc0(param_1);
      return;
    }
    FUN_00439bf0((undefined4 *)0x6,(byte *)param_1,this);
    FUN_0041ddc0(param_1);
    return;
  }
  _DAT_004fdb20 = this;
  FUN_0042ab30(&DAT_005090b0,0x58,(int *)&DAT_004fdb20);
  return;
switchD_00439c14_caseD_16:
  iVar3 = *(int *)(this + 0xc);
  if (*(int *)(iVar3 + 0x98) == 0) {
    return;
  }
  if (pbVar6 != (byte *)0x0) {
    *(uint *)(iVar3 + 0x74) = (uint)(*(int *)(iVar3 + 0x74) == 0);
  }
  FUN_00435510(this);
  FUN_00434270(this,4);
  uVar1 = 2;
  pbVar6 = (byte *)0x1;
  goto LAB_00439c0c;
}

