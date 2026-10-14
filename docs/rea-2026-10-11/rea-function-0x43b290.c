
void __thiscall FUN_0043b260(void *this,short param_1,undefined4 param_2)

{
  uint uVar1;
  uint uVar2;
  bool bVar3;
  int iVar4;
  undefined3 extraout_var;
  
  iVar4 = FUN_0041f060(&DAT_004e48b8,(int)param_1);
  uVar1 = *(uint *)(iVar4 + 4);
  uVar2 = *(uint *)(iVar4 + 8);
  iVar4 = FUN_0041f040(&DAT_004e48b8,uVar1);
  FUN_00436810(this,uVar1,1);
  FUN_0043cb00(DAT_004fe7ac,0x1a,(byte *)(int)param_1,this);
  FUN_00434c40(this,1,&param_1,0);
  bVar3 = FUN_00436310(this);
  if (CONCAT31(extraout_var,bVar3) != 0) {
    iVar4 = (**(code **)(iVar4 + 0x21c))(uVar2 & 1,uVar1,this,param_2);
    if (iVar4 == 0) {
      return;
    }
    if (iVar4 == 3) {
      return;
    }
    if (iVar4 != 1) {
      return;
    }
  }
  FUN_0043cb00(DAT_004fe7ac,0x18,(byte *)((*(uint *)((int)this + 0x38) | 0x100) << 0x10 | uVar1),
               this);
  return;
}

