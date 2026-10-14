
void __thiscall FUN_00423af0(void *this,void *param_1,float param_2,int param_3)

{
  *(undefined4 *)((int)this + 0x7c) = *(undefined4 *)((int)this + 0x78);
  *(float *)((int)this + 0x80) = param_2;
  *(void **)((int)this + 0x78) = param_1;
  *(int *)((int)this + 0x74) = param_3;
  *(undefined4 *)((int)this + 0x84) = 0;
  FUN_0042bd60(param_1,param_2,param_3,(float *)((int)this + 0x10),(float *)((int)this + 0x1c),
               (void *)((int)this + 0x28));
  return;
}

