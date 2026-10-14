
short __thiscall FUN_0041ec70(void *this,int param_1)

{
  int *piVar1;
  short sVar2;
  int iVar3;
  int iVar4;
  int local_804;
  short local_800 [1024];
  
  local_804 = 0;
  if (param_1 == -1) {
    iVar4 = 0x27;
    iVar3 = 0;
  }
  else if (param_1 == 1) {
    iVar4 = 0xc;
    iVar3 = 8;
  }
  else {
    if (param_1 != 2) {
      return -1;
    }
    iVar4 = 7;
    iVar3 = 0;
  }
  FUN_0041ebf0(this,(int)local_800,&local_804,iVar3,iVar4);
  if (local_804 == 0) {
    return -1;
  }
  iVar3 = _rand();
  sVar2 = local_800[iVar3 % local_804];
  iVar3 = (int)sVar2;
  *(uint *)((int)this + iVar3 * 0xc + 0x6dc0) = *(uint *)((int)this + iVar3 * 0xc + 0x6dc0) | 4;
  piVar1 = (int *)(*(int *)((int)this + (iVar3 * 3 + 0x1b6f) * 4) * 0x230 + 0x118 + (int)this);
  *piVar1 = *piVar1 + -1;
  *(int *)((int)this + 0x852c) = *(int *)((int)this + 0x852c) + -1;
  return sVar2;
}

