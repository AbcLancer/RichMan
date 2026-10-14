
void __thiscall FUN_00432ae0(void *this,int param_1)

{
  int iVar1;
  
  iVar1 = param_1;
  FUN_004026c0(DAT_004a6040,(char *)&param_1,4,param_1);
  if (-1 < param_1) {
    if (DAT_004e1b1c == 0) {
      *(undefined **)this = &DAT_004f1b10 + param_1 * 0x1e0;
    }
    else {
      *(undefined **)this = &DAT_004e1b80 + param_1 * 0x1e0;
    }
  }
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 4),4,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 8),0x10,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x18),4,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x1c),4,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x30),4,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x34),4,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x38),4,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x3c),4,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x40),1,iVar1);
  FUN_004026c0(DAT_004a6040,(char *)((int)this + 0x54),0xc,iVar1);
  return;
}

