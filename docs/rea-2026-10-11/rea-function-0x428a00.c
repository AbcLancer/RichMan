
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_00428a00(void *this,double param_1)

{
  int iVar1;
  float fVar2;
  int iVar3;
  int *piVar4;
  int *piVar5;
  byte *pbVar6;
  float10 fVar7;
  int *local_18;
  float *local_14;
  int local_10;
  
  pbVar6 = (byte *)0x0;
  local_10 = 0;
  if (0 < *(int *)((int)this + 0x20)) {
    local_14 = (float *)((int)this + 0x30);
    local_18 = (int *)((int)this + 0x2c);
    piVar5 = (int *)((int)this + 0x28);
    piVar4 = (int *)((int)this + 0x24);
    do {
      iVar3 = *local_18;
      if (0 < iVar3) {
        pbVar6 = (byte *)*piVar4;
        iVar1 = *piVar5;
        fVar7 = FUN_0042bb30((int)pbVar6,iVar1);
        fVar2 = (float)_DAT_00508f2c * 100.0 * (float)param_1;
        fVar2 = fVar2 + fVar2 + *local_14;
        while ((float)fVar7 <= fVar2) {
          fVar2 = fVar2 - (float)fVar7;
          iVar3 = iVar3 + -1;
          pbVar6 = (byte *)FUN_0042bb70(iVar1,1);
          if (*(int *)(pbVar6 + 0x34) != -1) {
            FUN_0042be40(pbVar6);
          }
        }
        *piVar4 = (int)pbVar6;
        *piVar5 = iVar1;
        *local_18 = iVar3;
        *local_14 = fVar2;
      }
      local_10 = local_10 + 4;
      local_14 = local_14 + 4;
      local_18 = local_18 + 4;
      piVar5 = piVar5 + 4;
      piVar4 = piVar4 + 4;
    } while (local_10 < *(int *)((int)this + 0x20));
    if (pbVar6 != (byte *)0x0) {
      return;
    }
  }
  *(undefined4 *)this = 0;
  return;
}

