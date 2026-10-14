
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

undefined4 __cdecl FUN_00439160(int *param_1,undefined4 param_2,int param_3)

{
  byte *this;
  byte *pbVar1;
  void *this_00;
  bool bVar2;
  undefined3 extraout_var;
  int iVar3;
  int iVar4;
  longlong lVar5;
  byte *pbVar6;
  uint uVar7;
  
  this = *(byte **)(param_1[3] + 0x78);
  if ((2 < param_1[0xf]) && (param_1[0xf] < 6)) {
    FUN_00434270(param_1,0);
  }
  FUN_0043c5e0(DAT_004fe7ac,2,(uint *)0x0,(int)param_1);
  bVar2 = FUN_00431c60(&DAT_004f2e68,this,param_1);
  if (CONCAT31(extraout_var,bVar2) == 0) {
    if (param_3 != 0) {
      return 0;
    }
    if ((((this[0x30] == 0) || (iVar3 = FUN_004363d0(param_1), iVar3 == 0)) ||
        (iVar3 = FUN_00439530(*(uint *)(this + 0x30) & 0xff,param_1,0), iVar3 == 0)) &&
       (iVar3 = FUN_0042bb50((int)this), iVar3 != 0)) {
      if ((*(int *)(iVar3 + 0x34) == 0) || (*(int *)(iVar3 + 0x34) == param_1[0x70])) {
        pbVar6 = (byte *)0x97;
      }
      else {
        pbVar6 = (byte *)0x96;
      }
      FUN_0042f9b0(pbVar6,this);
      iVar4 = *(int *)(iVar3 + 0x34);
      if (iVar4 != 0) {
        if ((*(int *)(iVar3 + 0x30) != 0) && (2 < *(int *)(*(int *)(iVar3 + 0x30) + 0x38))) {
          FUN_00438d70(iVar3,param_1);
          return 1;
        }
        if ((iVar4 != 0) && (iVar4 != param_1[0x70])) {
          if (*(int *)(*(int *)(this + 0x3c) + 0x28) != 0) {
            FUN_00436570(param_1,0xe);
            return 1;
          }
          lVar5 = FUN_0042bf90(this,1);
          pbVar6 = (byte *)lVar5;
          if (pbVar6 == (byte *)0x0) {
            _DAT_004fdb24 = *(int **)(*(int *)(iVar3 + 0x34) + 0x2e0);
            uVar7 = 0x56;
          }
          else {
            iVar4 = FUN_00435fe0(param_1,0);
            if (((iVar4 == 0) && (iVar4 = FUN_00435fe0(param_1,0xb), iVar4 == 0)) &&
               (iVar4 = FUN_00435fe0(param_1,9), iVar4 == 0)) {
              iVar4 = FUN_00435fe0(param_1,6);
              if (iVar4 == 0) {
                _DAT_004fdb20 = param_1;
                _DAT_004fdb24 = *(int **)(*(int *)(iVar3 + 0x34) + 0x2e0);
                DAT_004fdb3c = *(undefined4 *)(this + 0x3c);
                uVar7 = 0x5e;
                _DAT_004fdb34 = pbVar6;
              }
              else {
                _DAT_004fdb20 = param_1;
                _DAT_004fdb24 = param_1;
                _DAT_004fdb28 = *(undefined4 *)(*(int *)(iVar3 + 0x34) + 0x2e0);
                pbVar6 = (byte *)((int)pbVar6 * 2);
                _DAT_004fdb34 = pbVar6;
                FUN_0042ab30(&DAT_005090b0,0x41c,(int *)&DAT_004fdb20);
                uVar7 = 0x57;
              }
              FUN_0042ab30(&DAT_005090b0,uVar7,(int *)&DAT_004fdb20);
              pbVar1 = *(byte **)(param_1[0x70] + 0x4c);
              bVar2 = false;
              if ((int)pbVar1 < (int)pbVar6) {
                bVar2 = true;
              }
              else {
                if (((int)pbVar1 * 0x23) / 100 < (int)pbVar6) {
                  iVar4 = 6;
                }
                else if ((int)pbVar6 < 0x2711) {
                  iVar4 = 4;
                }
                else {
                  iVar4 = 5;
                }
                FUN_00436570(param_1,iVar4);
              }
              FUN_0043ff30((void *)param_1[0x70],pbVar6,0);
              if ((int)pbVar1 < (int)pbVar6) {
                pbVar6 = pbVar1;
              }
              FUN_0043ffe0(*(void **)(iVar3 + 0x34),pbVar6,0);
              FUN_0043cb00(DAT_004fe7ac,0x3f3,(byte *)((int)pbVar6 << 8 | param_1[0xe]),
                           (byte *)((uint)(*(int *)(this + 0x28) - DAT_004e3844) / 0x58 |
                                   *(int *)(this + 0x2c) << 8));
              this_00 = *(void **)(*(int *)(iVar3 + 0x34) + 0x2e0);
              if ((bVar2) && (iVar3 = FUN_0043a910(0x4f1b08), iVar3 == 2)) {
                return 1;
              }
              iVar3 = FUN_0041a950(&DAT_004e3b28,3);
              if (iVar3 * 10000 <= (int)pbVar6) {
                FUN_00436570(this_00,0xd);
                return 1;
              }
              iVar3 = FUN_0041a950(&DAT_004e3b28,3);
              if (iVar3 * 0x9c4 <= (int)pbVar6) {
                FUN_00436570(this_00,0xc);
                return 1;
              }
              FUN_00436570(this_00,0xb);
              return 1;
            }
            iVar3 = FUN_00435fe0(param_1,0);
            if (iVar3 == 0) {
              iVar3 = FUN_00435fe0(param_1,0xb);
              uVar7 = 0x41e;
              if (iVar3 == 0) goto LAB_004392ac;
            }
            uVar7 = 0x41b;
          }
LAB_004392ac:
          _DAT_004fdb20 = param_1;
          FUN_0042ab30(&DAT_005090b0,uVar7,(int *)&DAT_004fdb20);
          FUN_00436570(param_1,0xe);
          return 1;
        }
      }
      iVar3 = FUN_00436390(param_1);
      if (iVar3 != 0) {
        FUN_00438ab0(param_1,(int)this);
      }
    }
  }
  return 1;
}

