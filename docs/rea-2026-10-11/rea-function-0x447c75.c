
void __fastcall FUN_00447b70(void *param_1)

{
  void *this;
  int iVar1;
  void *this_00;
  uint uVar2;
  int iVar3;
  float10 extraout_ST0;
  longlong lVar4;
  float fVar5;
  undefined4 uVar6;
  undefined4 uVar7;
  undefined4 uVar8;
  undefined4 uVar9;
  undefined4 uVar10;
  undefined4 uVar11;
  
  iVar3 = DAT_004e2a84;
  iVar1 = FUN_00435630(&DAT_004e1b80 + DAT_004e2a84 * 0x1e0,0xff);
  this_00 = param_1;
  if (-1 < iVar1) {
    this_00 = (void *)FUN_00433040(&DAT_004c7048,iVar1);
    uVar10 = *(undefined4 *)((int)param_1 + 0x78);
    uVar11 = *(undefined4 *)(*(int *)((int)param_1 + 0xd0) + 0xd8);
    fVar5 = (*(float *)((int)param_1 + 0x28) + *(float *)((int)param_1 + 0x20)) - 0.34666666;
    uVar9 = 0x3da00000;
    uVar8 = 0x3f610000;
    uVar7 = 0x3c000000;
    uVar6 = 0x3f2f0000;
    lVar4 = __ftol();
    FUN_00459850(*(float *)((int)param_1 + 0x1c) + 0.2275,
                 (float)(extraout_ST0 - (float10)0.38333333),
                 (float)(0x5b - (int)lVar4) * 0.0025 + *(float *)((int)param_1 + 0x1c),fVar5,uVar6,
                 uVar7,uVar8,uVar9,uVar10,uVar11);
  }
  if (iVar1 != -1) {
    iVar1 = FUN_00447d20();
    if (iVar1 == 0) {
      uVar2 = 0;
    }
    else {
      lVar4 = __ftol();
      uVar2 = (uint)lVar4 & 0x80000001;
      if ((int)uVar2 < 0) {
        uVar2 = (uVar2 - 1 | 0xfffffffe) + 1;
      }
    }
    if ((&DAT_004e1bbc)[iVar3 * 0x78] == 6) {
      uVar2 = 0;
    }
    iVar3 = FUN_00432930(this_00,uVar2);
    if (iVar3 != 0) {
      FUN_00448810(*(void **)((int)param_1 + 0xd4),iVar3,iVar3,0);
      (**(code **)(**(int **)((int)param_1 + 0xd4) + 0xc))();
    }
    this = (void *)**(undefined4 **)(DAT_0050d0d4 + 200);
    *(undefined4 *)((int)this + 0x30) = 0x3d23d70a;
    *(undefined4 *)((int)this + 0x34) = 0x3d5a740e;
    *(undefined4 *)((int)this + 0x2c) = 0xffffffff;
    fVar5 = *(float *)((int)param_1 + 0x28) + *(float *)((int)param_1 + 0x20);
    FUN_0040b8d0(this,(char *)((int)this_00 + 8),*(float *)((int)param_1 + 0x1c) + 0.2375,
                 fVar5 - 0.30666667,*(float *)((int)param_1 + 0x1c) + 0.355,fVar5 - 0.26666668);
  }
  return;
}

