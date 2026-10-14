
void __thiscall FUN_0041d800(void *this,int param_1,int param_2)

{
  float *pfVar1;
  float fVar2;
  float fVar3;
  float fVar4;
  float fVar5;
  float fVar6;
  int iVar7;
  int iVar8;
  int iVar9;
  int iVar10;
  int iVar11;
  int iVar12;
  float local_18;
  
  if (param_2 == 0) {
    param_2 = *(int *)(param_1 * 0x40 + 0x30 + *(int *)((int)this + 0x54));
    local_18 = -1.0;
  }
  else {
    local_18 = 1.0;
  }
  fVar2 = (float)*(int *)(param_2 + 0x34) * 0.5;
  fVar3 = (float)(param_1 % *(int *)((int)this + 0x4c)) + fVar2;
  fVar2 = (float)(param_1 / *(int *)((int)this + 0x4c)) + fVar2;
  fVar4 = ((float)*(int *)(param_2 + 0x34) + 1.0) * 1.5;
  iVar8 = FUN_00405230(fVar3 - fVar4);
  iVar9 = FUN_00405230(fVar4 + fVar3);
  iVar10 = FUN_00405230(fVar2 - fVar4);
  iVar11 = FUN_00405230(fVar4 + fVar2);
  for (; iVar10 <= iVar11; iVar10 = iVar10 + 1) {
    if ((-1 < iVar10) && (iVar7 = iVar8, iVar10 < *(int *)((int)this + 0x50))) {
      for (; iVar7 <= iVar9; iVar7 = iVar7 + 1) {
        if (((-1 < iVar7) && (iVar7 < *(int *)((int)this + 0x4c))) &&
           (iVar12 = FUN_0042b1c0(this,iVar7,iVar10), (*(byte *)(iVar12 + 0xc) & 2) != 0)) {
          fVar5 = (fVar3 - (float)iVar7) - 0.5;
          fVar6 = (fVar2 - (float)iVar10) - 0.5;
          fVar5 = 1.0 - SQRT(fVar5 * fVar5 + fVar6 * fVar6) / fVar4;
          if (fVar5 < 0.0) {
            fVar5 = 0.0;
          }
          fVar5 = fVar5 * local_18;
          pfVar1 = (float *)(iVar12 + 0x28);
          *pfVar1 = (float)*(int *)(param_2 + 0x44) * fVar5 + *pfVar1;
          *(float *)(iVar12 + 0x1c) =
               (float)*(int *)(param_2 + 0x48) * fVar5 + *(float *)(iVar12 + 0x1c);
          *(float *)(iVar12 + 0x20) =
               (float)*(int *)(param_2 + 0x4c) * fVar5 + *(float *)(iVar12 + 0x20);
          *(float *)(iVar12 + 0x24) =
               (float)*(int *)(param_2 + 0x50) * fVar5 + *(float *)(iVar12 + 0x24);
          FUN_0042aea0(pfVar1);
        }
      }
    }
  }
  return;
}

