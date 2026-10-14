
void __thiscall FUN_00429780(void *this,int param_1)

{
  int iVar1;
  
  iVar1 = param_1;
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0xd18),0xc,param_1);
  if (*(int *)((int)this + 0xd24) == 0) {
    param_1 = -1;
  }
  else {
    param_1 = *(int *)(*(int *)((int)this + 0xd24) + 0x38);
  }
  FUN_00402790(DAT_004a6040,(char *)&param_1,4,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0xd28),4,iVar1);
  FUN_00402790(DAT_004a6040,(char *)((int)this + 0xd30),8,iVar1);
  return;
}

