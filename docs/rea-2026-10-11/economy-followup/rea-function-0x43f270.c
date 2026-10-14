
void * __fastcall FUN_0043f270(void *param_1)

{
  int iVar1;
  longlong lVar2;
  
  iVar1 = *(int *)((int)param_1 + 0x48);
  if (iVar1 == 0) {
    lVar2 = FUN_00440700(param_1,0);
    return (void *)((int)lVar2 + *(int *)((int)param_1 + 0x50) + *(int *)((int)param_1 + 0x4c));
  }
  if (iVar1 != 1) {
    if (iVar1 == 2) {
      lVar2 = FUN_00440700(param_1,0);
      return (void *)((int)lVar2 + *(int *)((int)param_1 + 0x4c));
    }
    return param_1;
  }
  return *(void **)((int)param_1 + 0x4c);
}

