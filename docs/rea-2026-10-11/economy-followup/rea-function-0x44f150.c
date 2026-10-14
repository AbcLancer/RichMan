
void __fastcall FUN_0044f150(int param_1)

{
  char cVar1;
  char *pcVar2;
  undefined4 uVar3;
  uint uVar4;
  uint uVar5;
  int *piVar6;
  char *pcVar7;
  char *pcVar8;
  int local_4;
  
  piVar6 = (int *)(param_1 + 0x168);
  FUN_00433540(piVar6,param_1 + 0xd8);
  pcVar7 = (char *)(param_1 + 0xe8);
  local_4 = 4;
  do {
    pcVar2 = FUN_00431e80(*piVar6);
    uVar4 = 0xffffffff;
    do {
      pcVar8 = pcVar2;
      if (uVar4 == 0) break;
      uVar4 = uVar4 - 1;
      pcVar8 = pcVar2 + 1;
      cVar1 = *pcVar2;
      pcVar2 = pcVar8;
    } while (cVar1 != '\0');
    uVar4 = ~uVar4;
    pcVar2 = pcVar8 + -uVar4;
    pcVar8 = pcVar7;
    for (uVar5 = uVar4 >> 2; uVar5 != 0; uVar5 = uVar5 - 1) {
      *(undefined4 *)pcVar8 = *(undefined4 *)pcVar2;
      pcVar2 = pcVar2 + 4;
      pcVar8 = pcVar8 + 4;
    }
    for (uVar4 = uVar4 & 3; uVar4 != 0; uVar4 = uVar4 - 1) {
      *pcVar8 = *pcVar2;
      pcVar2 = pcVar2 + 1;
      pcVar8 = pcVar8 + 1;
    }
    uVar3 = FUN_004328d0(*piVar6,0,0);
    FUN_00448810((void *)piVar6[-0x28],uVar3,uVar3,0);
    pcVar2 = (char *)FUN_0042a8f0(&DAT_005090b0,*piVar6 + 0x897);
    FUN_00457b80((void *)piVar6[-0x28],pcVar2);
    piVar6 = piVar6 + 1;
    pcVar7 = pcVar7 + 0x20;
    local_4 = local_4 + -1;
    if (local_4 == 0) {
      return;
    }
  } while( true );
}

