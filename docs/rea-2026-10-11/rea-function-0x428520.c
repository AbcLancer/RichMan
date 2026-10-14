
void __thiscall FUN_00428520(void *this,void *param_1,int param_2,int param_3)

{
  int iVar1;
  
  *(void **)((int)this + *(int *)((int)this + 0x20) * 4 + 0x24) = param_1;
  iVar1 = *(int *)((int)this + 0x20) + 1;
  *(int *)((int)this + 0x20) = iVar1;
  *(int *)((int)this + iVar1 * 4 + 0x24) = param_2;
  iVar1 = *(int *)((int)this + 0x20) + 1;
  *(int *)((int)this + 0x20) = iVar1;
  *(int *)((int)this + iVar1 * 4 + 0x24) = param_3;
  *(int *)((int)this + 0x20) = *(int *)((int)this + 0x20) + 1;
  iVar1 = FUN_0042b1b0(param_1,param_2);
  if (*(int *)(iVar1 + 0x30) != 0) {
    FUN_0041cf40(param_1,*(int *)(iVar1 + 0x14),param_3,*(int *)(iVar1 + 0x34),'\x01');
    FUN_0041d9e0(param_1,0);
  }
  return;
}

