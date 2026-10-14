
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

undefined4 __cdecl FUN_00439530(int param_1,void *param_2,int param_3)

{
  int iVar1;
  byte *pbVar2;
  uint *puVar3;
  int iVar4;
  int iVar5;
  void *this;
  short *psVar6;
  int *piVar7;
  uint uVar8;
  int aiStackY_c8 [5];
  short local_9c [10];
  undefined4 local_88;
  uint local_84;
  int local_80 [8];
  int local_60 [24];
  
  switch(param_1) {
  case 2:
    if (param_3 == 0) {
      _DAT_004fdb20 = param_2;
      if (*(int *)((int)param_2 + 0x114) < 0xb) {
        FUN_0042ab30(&DAT_005090b0,0x2a,(int *)&DAT_004fdb20);
        return 1;
      }
      local_84 = FUN_0041ee60(&DAT_004e48b8,local_9c,8);
      if (*(int *)((int)param_2 + 0x34) != 3) {
        local_88 = *(undefined4 *)((int)DAT_004fe7ac + 0x8008);
        if (0 < (int)local_84) {
          piVar7 = local_80;
          psVar6 = local_9c;
          uVar8 = local_84;
          do {
            *piVar7 = (int)*psVar6;
            psVar6 = psVar6 + 1;
            piVar7 = piVar7 + 1;
            uVar8 = uVar8 - 1;
          } while (uVar8 != 0);
        }
        FUN_00434310(param_2,100,&local_88,local_84 + 2);
        FUN_0043c5e0(DAT_004fe7ac,6,&local_84,(int)param_2);
        return 1;
      }
      FUN_0041c390(param_2,local_84,local_9c);
      return 1;
    }
    break;
  case 3:
    if ((param_3 == 0) && (iVar1 = FUN_00405130(DAT_00508e38,DAT_00508e3c), iVar1 != 0)) {
      FUN_00436570(param_2,9);
      FUN_00436a10(param_2,1,iVar1 * 0x18);
      _DAT_004fdb24 = param_2;
      _DAT_004fdb20 = param_2;
      FUN_0042ab30(&DAT_005090b0,1,(int *)&DAT_004fdb20);
      return 1;
    }
    break;
  case 4:
    if (param_3 == 0) {
      aiStackY_c8[4] = 0x4396d6;
      FUN_00439b80(param_2,2,-1,0);
      FUN_00436570(param_2,0xd);
    }
    else {
      aiStackY_c8[4] = 0x4396c2;
      FUN_00439b80(param_2,1,-1,0);
    }
    FUN_0042f9b0((byte *)0x10,*(void **)(*(int *)((int)param_2 + 0xc) + 0x78));
    return 1;
  case 5:
    if (param_3 == 0) {
      FUN_00431090(param_2);
      return 1;
    }
    break;
  case 6:
    if ((param_3 == 0) && (*(int *)((int)param_2 + 0x34) != 3)) {
      FUN_0043c5e0(DAT_004fe7ac,0xb,(uint *)0x0,(int)param_2);
      return 1;
    }
    break;
  case 7:
    if (param_3 == 0) {
      iVar1 = FUN_00405130(1,8);
      iVar4 = thunk_FUN_00441900(&DAT_004e3b48);
      iVar5 = FUN_00405130(2,10);
      pbVar2 = (byte *)((iVar4 * iVar5) / 100);
      this = (void *)0x0;
      switch(iVar1) {
      case 1:
        iVar4 = FUN_00441450(0x4e3b48);
        this = (void *)FUN_00440170(iVar4);
        break;
      case 2:
        iVar4 = FUN_004414a0(0x4e3b48);
        this = (void *)FUN_00440170(iVar4);
        break;
      case 3:
        iVar4 = FUN_00441510(0x4e3b48);
        this = (void *)FUN_00440170(iVar4);
        break;
      case 4:
        iVar4 = FUN_00441580(0x4e3b48);
        this = (void *)FUN_00440170(iVar4);
        break;
      case 5:
        iVar4 = FUN_004415f0(0x4e3b48);
        this = (void *)FUN_00440170(iVar4);
        break;
      case 6:
        iVar4 = FUN_00441660(0x4e3b48);
        this = (void *)FUN_00440170(iVar4);
        break;
      case 7:
        iVar4 = FUN_004416b0(0x4e3b48);
        this = (void *)FUN_00440170(iVar4);
        break;
      case 8:
        this = (void *)FUN_00438d10(0x4f1b08);
      }
      _DAT_004fdb24 = this;
      if (iVar1 < 6) {
        FUN_00434ae0(this,0,(short *)0x0,100);
      }
      else {
        FUN_0043ffe0(*(void **)((int)this + 0x1c0),pbVar2,0);
        _DAT_004fdb34 = pbVar2;
      }
      FUN_0042ab30(&DAT_005090b0,iVar1 + 0x15,(int *)&DAT_004fdb20);
      _DAT_004fdb20 = param_2;
      FUN_0042ab30(&DAT_005090b0,iVar1 + 0xce4,(int *)&DAT_004fdb20);
      return 1;
    }
    break;
  case 8:
    if (param_3 == 0) {
      if (*(int *)((int)param_2 + 0x34) == 3) {
        FUN_0041c700(param_2);
      }
      else {
        iVar1 = FUN_00435680((int)param_2);
        if (-1 < iVar1) {
          FUN_00434280(param_2,0x66,*(undefined4 *)((int)DAT_004fe7ac + 0x8008));
          FUN_0043c5e0(DAT_004fe7ac,0xd,(uint *)0x0,(int)param_2);
        }
      }
      _DAT_004fdb20 = param_2;
      iVar1 = FUN_00435680((int)param_2);
      if (iVar1 < 0) {
        FUN_0042ab30(&DAT_005090b0,0xca,(int *)&DAT_004fdb20);
        return 1;
      }
      FUN_0042ab30(&DAT_005090b0,0xc9,(int *)&DAT_004fdb20);
      return 1;
    }
    break;
  case 9:
  case 10:
    if (param_3 == 0) {
      iVar1 = FUN_00405130(0x28,0x3c);
      FUN_00434ae0(param_2,0,(short *)0x0,iVar1);
      _DAT_004fdb20 = param_2;
      _DAT_004fdb34 = (byte *)iVar1;
      FUN_0042ab30(&DAT_005090b0,4,(int *)&DAT_004fdb20);
      return 1;
    }
    break;
  case 0xb:
  case 0xc:
  case 0xd:
  case 0xe:
  case 0xf:
    if (param_3 == 0) {
      local_9c[0] = 5;
      local_9c[1] = 0;
      local_9c[2] = 10;
      local_9c[3] = 0;
      local_9c[4] = 0x14;
      local_9c[5] = 0;
      local_9c[6] = 0x1e;
      local_9c[7] = 0;
      local_9c[8] = 0x32;
      local_9c[9] = 0;
      FUN_00434ae0(param_2,0,(short *)0x0,aiStackY_c8[param_1]);
    }
    break;
  case 0x10:
    if (param_3 == 0) {
      iVar1 = FUN_00429ca0(&DAT_004e3b80,*(int *)((int)param_2 + 0x38),local_60);
      if (5 < iVar1) {
        _DAT_004fdb20 = param_2;
        FUN_0042ab30(&DAT_005090b0,0x44,(int *)&DAT_004fdb20);
        return 1;
      }
      iVar1 = FUN_00435620((int)param_2);
      if (*(int *)(iVar1 + 0x4c) < 0x3e9) {
        _DAT_004fdb20 = param_2;
        FUN_0042ab30(&DAT_005090b0,0x58,(int *)&DAT_004fdb20);
        return 1;
      }
      if (*(int *)((int)param_2 + 0x34) != 3) {
        puVar3 = (uint *)FUN_0041a950(&DAT_004e3b28,1);
        FUN_0043c5e0(DAT_004fe7ac,0x32,puVar3,(int)param_2);
        return 1;
      }
      iVar1 = FUN_00435620((int)param_2);
      if ((10000 < *(int *)(iVar1 + 0x4c)) &&
         (pbVar2 = (byte *)FUN_00429db0(0x4e3b80), -1 < (int)pbVar2)) {
        FUN_00429df0(&DAT_004e3b80,pbVar2,(int)param_2);
        return 1;
      }
    }
  }
  return 1;
}

