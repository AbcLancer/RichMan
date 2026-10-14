
void FUN_0042e9e0(float param_1,int param_2)

{
  float *pfVar1;
  float *pfVar2;
  float fVar3;
  int iVar4;
  int iVar5;
  
  iVar5 = 0;
  if (0 < *(int *)(param_2 + 0x20)) {
    do {
      iVar4 = FUN_0042bb50(*(int *)(*(int *)(param_2 + 0x24) + iVar5 * 4));
      if (iVar4 != 0) {
        pfVar1 = (float *)(iVar4 + 0x28);
        pfVar2 = (float *)(iVar4 + 0x2c);
        fVar3 = ABS(*(float *)(iVar4 + 0x28)) * param_1 + *pfVar1;
        *pfVar1 = fVar3;
        *pfVar2 = ABS(fVar3) * param_1 + *pfVar2;
        FUN_0042aea0(pfVar1);
        FUN_0042aea0(pfVar2);
      }
      iVar5 = iVar5 + 1;
    } while (iVar5 < *(int *)(param_2 + 0x20));
  }
  return;
}

