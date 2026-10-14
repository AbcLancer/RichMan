
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00433f00(void *this,float param_1,undefined4 param_2)

{
  double dVar1;
  bool bVar2;
  int *piVar3;
  undefined3 extraout_var;
  undefined3 extraout_var_00;
  int iVar4;
  byte *pbVar5;
  undefined3 extraout_var_01;
  undefined3 extraout_var_02;
  undefined4 uVar6;
  int extraout_ECX;
  byte *pbVar7;
  
  if (*(int *)((int)this + 0x17c) != -1) {
    piVar3 = (int *)FUN_00433040(&DAT_004e3b18,*(int *)((int)this + 0x17c));
    FUN_00432130((int)piVar3);
    if ((float)piVar3[0xe] <= 0.0) {
      FUN_004320b0(piVar3);
    }
  }
  if (0 < DAT_004f2a44) {
    FUN_00433e20(this,1);
    if (((*(int *)((int)this + 0x34) == 3) &&
        (bVar2 = FUN_00436410(), CONCAT31(extraout_var,bVar2) != 0)) &&
       (bVar2 = FUN_00434200(extraout_ECX), CONCAT31(extraout_var_00,bVar2) != 0)) {
      FUN_0041c780((int)this);
    }
    if (*(int *)((int)this + 0x3c) == 2) {
      FUN_00433ca0(this,1);
      return;
    }
    iVar4 = FUN_00435fe0(this,3);
    if ((iVar4 != 0) && (iVar4 = FUN_00436230(this,3), iVar4 != 0)) {
      FUN_00434270(this,3);
      pbVar7 = this;
      pbVar5 = (byte *)FUN_00405130(1,6);
      FUN_00439bf0((undefined4 *)0x3,pbVar5,pbVar7);
    }
  }
  if (*(int *)((int)this + 0x3c) != 2) {
    dVar1 = *(double *)((int)this + 0x1c8);
    *(double *)((int)this + 0x1c8) =
         (double)CONCAT44(param_2,param_1) + *(double *)((int)this + 0x1c8);
    if (*(int *)((int)this + 0x34) == 3) {
      if (*(int *)(*(int *)((int)this + 0xc) + 0x98) == 0) {
        *(undefined4 *)((int)this + 0x1c8) = 0;
        *(undefined4 *)((int)this + 0x1cc) = 0;
      }
      if (*(double *)((int)this + 0x1d0) <= *(double *)((int)this + 0x1c8)) {
        iVar4 = FUN_004810b0();
        if ((((((iVar4 == 0) || (iVar4 = FUN_0041c530(this), iVar4 == 0)) &&
              (bVar2 = FUN_00436310(this), CONCAT31(extraout_var_01,bVar2) != 0)) &&
             (bVar2 = FUN_00434180((int)this), CONCAT31(extraout_var_02,bVar2) != 0)) &&
            (((iVar4 = FUN_0041c4c0(this), iVar4 == 0x1a || (iVar4 == 0x29)) || (iVar4 == 0x26))))
           && (dVar1 = *(double *)((int)this + 0x1c8) - 8.0, *(double *)((int)this + 0x1c8) = dVar1,
              dVar1 < 0.0)) {
          *(undefined4 *)((int)this + 0x1c8) = 0;
          *(undefined4 *)((int)this + 0x1cc) = 0;
        }
        if ((*(double *)((int)this + 0x1d0) <= *(double *)((int)this + 0x1c8)) &&
           (iVar4 = FUN_00435fe0(this,3), iVar4 == 0)) {
          FUN_0041c950(this);
        }
      }
    }
    else {
      if ((*(int *)((int)this + 0x178) < DAT_0049e96c) ||
         (*(int *)(*(int *)((int)this + 0xc) + 0x98) == 0)) {
        *(undefined4 *)((int)this + 0x1c8) = 0;
        *(undefined4 *)((int)this + 0x1cc) = 0;
      }
      if ((_DAT_00508fa0 <= (float)*(double *)((int)this + 0x1c8)) &&
         (dVar1 < (double)_DAT_00508fa0)) {
        _DAT_004fdb20 = this;
        _DAT_004fdb24 = this;
        FUN_0042ab30(&DAT_005090b0,0x55,(int *)&DAT_004fdb20);
        FUN_00436570(this,0x10);
      }
    }
    iVar4 = *(int *)((int)this + 0x178);
    if (*(int *)((int)this + 0x3c) == 5) {
      iVar4 = 1000;
    }
    uVar6 = FUN_00423b90(*(void **)((int)this + 0xc),param_1,param_2,iVar4);
    FUN_00433d40(this,(byte)uVar6);
    return;
  }
  *(undefined4 *)((int)this + 0x1c8) = 0;
  *(undefined4 *)((int)this + 0x1cc) = 0;
  return;
}

