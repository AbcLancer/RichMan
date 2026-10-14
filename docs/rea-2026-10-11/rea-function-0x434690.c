
int __thiscall FUN_00434650(void *this,int param_1,undefined4 *param_2)

{
  int iVar1;
  undefined4 *puVar2;
  int iVar3;
  
  iVar3 = 0;
  if (0 < *(int *)((int)this + param_1 * 0x1c + 0x98)) {
    puVar2 = (undefined4 *)((int)this + param_1 * 0x1c + 0x84);
    do {
      *param_2 = *puVar2;
      iVar1 = *(int *)((int)this + param_1 * 0x1c + 0x98);
      iVar3 = iVar3 + 1;
      puVar2 = puVar2 + 1;
      param_2 = param_2 + 1;
    } while (iVar3 < iVar1);
    return iVar1;
  }
  return *(int *)((int)this + param_1 * 0x1c + 0x98);
}

