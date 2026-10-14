
void __fastcall FUN_004429d0(int param_1)

{
  double dVar1;
  int *this;
  float *pfVar2;
  uint uVar3;
  int iVar4;
  int iVar5;
  float *pfVar6;
  int iVar7;
  float10 fVar8;
  float10 fVar9;
  ulonglong uVar10;
  int local_128;
  float fStack_114;
  float fStack_110;
  float fStack_10c;
  float local_108 [5];
  undefined4 local_f4;
  float local_f0;
  float local_e4;
  undefined4 local_e0;
  undefined4 local_d8;
  undefined4 local_d4;
  float local_c8 [16];
  float local_88 [12];
  float local_58;
  float local_50;
  float afStack_48 [17];
  
  FUN_00403ee0(local_108);
  FUN_004042a0(local_108);
  local_e0 = 0;
  local_f4 = 0;
  local_108[0] = 1.0 / (*(float *)(param_1 + 0x11a14) - *(float *)(param_1 + 0x11a0c));
  local_d8 = 0x3f000000;
  local_d4 = 0x3f000000;
  local_f0 = 1.0 / (*(float *)(param_1 + 0x11a18) - *(float *)(param_1 + 0x11a10));
  local_e4 = local_f0;
  FUN_00403ee0(local_c8);
  this = *(int **)(DAT_0050d0d4 + 0xd0);
  pfVar2 = (float *)FUN_00405050(this);
  pfVar6 = local_c8;
  for (iVar4 = 0x10; iVar4 != 0; iVar4 = iVar4 + -1) {
    *pfVar6 = *pfVar2;
    pfVar2 = pfVar2 + 1;
    pfVar6 = pfVar6 + 1;
  }
  FUN_004043d0(local_c8);
  FUN_00403ee0(local_88);
  FUN_004042a0(local_88);
  local_58 = (*(float *)(param_1 + 0x11a0c) + *(float *)(param_1 + 0x11a14)) * -0.5;
  local_50 = (*(float *)(param_1 + 0x11a10) + *(float *)(param_1 + 0x11a18)) * -0.5;
  FUN_00403f90(local_c8,local_88);
  FUN_00403f90(local_c8,local_108);
  uVar3 = FUN_00405460(&DAT_0049ef14);
  local_128 = 0;
  if (0 < *(int *)(param_1 + 0x1c)) {
    do {
      iVar4 = *(int *)(*(int *)(*(int *)(param_1 + 0x20) + local_128 * 4) + 0xd0);
      iVar7 = 0;
      if (0 < *(int *)(iVar4 + 0x20)) {
        iVar5 = 0;
        do {
          FUN_00401490(*(void **)(iVar5 + 4 + *(int *)(iVar4 + 0x1c)),uVar3,local_c8);
          iVar7 = iVar7 + 1;
          iVar5 = iVar5 + 0xa8;
        } while (iVar7 < *(int *)(iVar4 + 0x20));
      }
      (**(code **)(**(int **)(*(int *)(param_1 + 0x20) + local_128 * 4) + 8))(0);
      local_128 = local_128 + 1;
    } while (local_128 < *(int *)(param_1 + 0x1c));
  }
  iVar4 = 0;
  if (0 < *(int *)(param_1 + 0x24)) {
    iVar7 = 0;
    do {
      FUN_00441ae0((int *)(iVar7 + *(int *)(param_1 + 0x28)));
      iVar4 = iVar4 + 1;
      iVar7 = iVar7 + 0xc;
    } while (iVar4 < *(int *)(param_1 + 0x24));
  }
  iVar7 = DAT_004c7494;
  iVar4 = FUN_00401cf0(param_1);
  FUN_00403ee0(afStack_48);
  do {
    if (iVar4 == 0) {
      return;
    }
    if ((*(float *)(iVar4 + 0x6c) <= 0.0) || (*(int *)(iVar4 + 0x70) != 0)) {
      pfVar2 = (float *)(iVar4 + 8);
      if (*(int *)(iVar4 + 0x54) == 0) {
        if (iVar7 != 0) goto LAB_00442ce3;
        if ((*(byte *)(iVar4 + 0x50) & 8) != 0) {
          dVar1 = *(double *)(iVar4 + 0x58);
          FUN_00403ef0(afStack_48,(int)pfVar2);
          fVar8 = FUN_00405170(-2.0,2.0);
          fVar9 = FUN_00405170(-2.0,2.0);
          fStack_114 = (float)fVar9;
          fStack_110 = ((float)dVar1 - 1.5) * 100.0 * 0.6666667;
          fStack_10c = (float)fVar8;
          FUN_004047d0(afStack_48,&fStack_114);
          pfVar2 = afStack_48;
        }
      }
      uVar3 = *(uint *)(iVar4 + 0x50);
      if ((uVar3 & 2) == 0) {
        if ((uVar3 & 4) == 0) {
          if ((uVar3 & 1) == 0) goto LAB_00442ca9;
          iVar5 = param_1 + 0x1197c;
        }
        else {
          uVar10 = __ftol();
          if ((uVar10 & 1) == 0) {
LAB_00442ca9:
            iVar5 = 0;
          }
          else {
            iVar5 = param_1 + 0x119c4;
          }
        }
      }
      else {
        iVar5 = param_1 + 0x119c4;
      }
      FUN_00404ea0(this);
      FUN_00404f30(this,pfVar2);
      if (*(int *)(iVar4 + 0x68) == 0) {
        (**(code **)(**(int **)(iVar4 + 0x48) + 8))(iVar5);
      }
      else {
        FUN_00406300(*(undefined4 **)(iVar4 + 0x48));
      }
      FUN_00404ed0((int)this);
    }
LAB_00442ce3:
    iVar4 = FUN_00401d00(param_1);
  } while( true );
}

