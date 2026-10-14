
int __thiscall FUN_0041ed50(void *this,int param_1,short *param_2,int param_3)

{
  uint *puVar1;
  short sVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  int local_804;
  short local_800 [1024];
  
  local_804 = 0;
  if (param_1 == -1) {
    iVar5 = 0x27;
    iVar4 = 0;
  }
  else if (param_1 == 1) {
    iVar5 = 0xc;
    iVar4 = 8;
  }
  else {
    if (param_1 != 2) {
      return 0;
    }
    iVar5 = 7;
    iVar4 = 0;
  }
  FUN_0041ebf0(this,(int)local_800,&local_804,iVar4,iVar5);
  if (local_804 == 0) {
    return 0;
  }
  FUN_00405340(local_800,local_804);
  if (local_804 <= param_3) {
    param_3 = local_804;
  }
  if (0 < param_3) {
    iVar5 = (int)local_800 - (int)param_2;
    iVar4 = param_3;
    do {
      sVar2 = *(short *)(iVar5 + (int)param_2);
      *param_2 = sVar2;
      puVar1 = (uint *)((int)this + sVar2 * 0xc + 0x6dc0);
      *puVar1 = *puVar1 | 4;
      iVar3 = *(int *)((int)this + (sVar2 * 3 + 0x1b6f) * 4) * 0x230;
      *(int *)(iVar3 + 0x118 + (int)this) = *(int *)(iVar3 + 0x118 + (int)this) + -1;
      param_2 = param_2 + 1;
      iVar4 = iVar4 + -1;
      *(int *)((int)this + 0x852c) = *(int *)((int)this + 0x852c) + -1;
    } while (iVar4 != 0);
  }
  return param_3;
}

