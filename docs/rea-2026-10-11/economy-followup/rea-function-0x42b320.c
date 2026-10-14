
void __thiscall FUN_0042b320(void *this,int param_1,float *param_2,float *param_3)

{
  int iVar1;
  int iVar2;
  float fVar3;
  float *pfVar4;
  float *pfVar5;
  int iVar6;
  int iVar7;
  int iVar8;
  
  pfVar5 = param_3;
  pfVar4 = param_2;
  iVar6 = FUN_0042b1b0(this,param_1);
  if (*(int *)(iVar6 + 0x30) == 0) {
    *param_2 = *(float *)(iVar6 + 0x28);
    *param_3 = *(float *)(iVar6 + 0x1c);
    param_3[1] = *(float *)(iVar6 + 0x20);
    param_3[2] = *(float *)(iVar6 + 0x24);
    return;
  }
  param_3[2] = 0.0;
  param_3[1] = 0.0;
  *param_3 = 0.0;
  *param_2 = 0.0;
  iVar1 = *(int *)(iVar6 + 0x14);
  iVar2 = *(int *)((int)this + 0x4c);
  param_2 = (float *)0x0;
  param_3 = (float *)0x0;
  iVar7 = *(int *)(*(int *)(iVar6 + 0x30) + 0x34);
  if (0 < iVar7) {
    do {
      iVar8 = 0;
      if (0 < iVar7) {
        do {
          iVar7 = FUN_0042b1c0(this,iVar8 + iVar1 % iVar2,(int)param_3 + iVar1 / iVar2);
          if ((*(byte *)(iVar7 + 0xc) & 2) != 0) {
            *pfVar4 = *(float *)(iVar7 + 0x28) + *pfVar4;
            *pfVar5 = *(float *)(iVar7 + 0x1c) + *pfVar5;
            pfVar5[1] = *(float *)(iVar7 + 0x20) + pfVar5[1];
            param_2 = (float *)((int)param_2 + 1);
            pfVar5[2] = *(float *)(iVar7 + 0x24) + pfVar5[2];
          }
          iVar8 = iVar8 + 1;
        } while (iVar8 < *(int *)(*(int *)(iVar6 + 0x30) + 0x34));
      }
      iVar7 = *(int *)(*(int *)(iVar6 + 0x30) + 0x34);
      param_3 = (float *)((int)param_3 + 1);
    } while ((int)param_3 < iVar7);
  }
  fVar3 = (float)(int)param_2;
  *pfVar4 = *pfVar4 / fVar3;
  *pfVar5 = *pfVar5 / fVar3;
  pfVar5[1] = pfVar5[1] / fVar3;
  pfVar5[2] = pfVar5[2] / fVar3;
  return;
}

