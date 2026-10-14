
void __thiscall FUN_0044e120(void *this,int *param_1)

{
  int iVar1;
  char *pcVar2;
  float local_78;
  float local_74;
  float local_70;
  float local_6c;
  int local_68 [25];
  
  if (*(int *)((int)this + 0x6c) != 0) {
    FUN_004580b0(this,param_1);
    return;
  }
  if (*param_1 == 3) {
    iVar1 = FUN_00429ca0(&DAT_004e2aa8,(&DAT_004e1bb8)[DAT_004e2a84 * 0x78],local_68);
    if (((iVar1 < 6) && (*(int *)((int)this + 0xf8) == 0)) && (*(int *)((int)this + 0xe8) == 0)) {
      pcVar2 = (char *)0x0;
      do {
        if (pcVar2[0x4e37c0] < '\0') {
          FUN_0044d950(this,(uint)pcVar2,&local_78,&local_70,&local_74,&local_6c);
          if (((local_78 < (float)param_1[2]) && ((float)param_1[2] < local_74)) &&
             ((local_70 < (float)param_1[3] && ((float)param_1[3] < local_6c)))) {
            FUN_00423ec0(DAT_004fe7b0,0x68,pcVar2,0);
            *(undefined4 *)((int)this + 0x108) = 0;
            *(undefined4 *)((int)this + 0xf8) = 1;
            *(undefined4 *)((int)this + 0x10c) = 0;
          }
        }
        pcVar2 = pcVar2 + 1;
      } while ((int)pcVar2 < 0xc);
    }
  }
  else if ((*param_1 == 0xc) && (param_1[5] == *(int *)((int)this + 0xdc))) {
    if (*(int *)((int)this + 0xe8) == 1) {
      FUN_0044d7d0((int)this);
    }
    FUN_0044e0a0((int)this);
    FUN_004580b0(this,param_1);
    return;
  }
  FUN_004580b0(this,param_1);
  return;
}

