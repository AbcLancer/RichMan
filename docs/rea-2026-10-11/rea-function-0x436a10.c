
void __thiscall FUN_00436a10(void *this,uint param_1,int param_2)

{
  FUN_00435510(this);
  FUN_00423250(*(void **)((int)this + 0xc),0);
  FUN_0043cb00(DAT_004fe7ac,0x1f7,(byte *)0x0,this);
  FUN_004342c0(this,2,param_1,param_2);
  FUN_0043cb00(DAT_004fe7ac,0x1f8,(byte *)(param_2 << 8 | param_1),this);
  return;
}

