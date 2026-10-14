
void __fastcall FUN_0044e9e0(int param_1)

{
  char cVar1;
  int iVar2;
  int iVar3;
  undefined4 uVar4;
  char *pcVar5;
  uint uVar6;
  uint uVar7;
  undefined4 *puVar8;
  int iVar9;
  char *pcVar10;
  char *local_10;
  int local_c;
  
  iVar9 = DAT_004e2a84 * 0x1e0;
  puVar8 = (undefined4 *)(param_1 + 200);
  local_10 = (char *)(param_1 + 0xe8);
  local_c = 0;
  do {
    iVar2 = FUN_00435630(&DAT_004e1b80 + iVar9,local_c);
    if (iVar2 == -1) {
      FUN_00457e90((void *)*puVar8,0);
      puVar8[4] = 0;
    }
    else {
      iVar3 = FUN_00433040(&DAT_004c7048,iVar2);
      uVar4 = FUN_004329d0(iVar3);
      puVar8[4] = *(undefined4 *)(iVar3 + 0x30);
      iVar2 = FUN_00433040(&DAT_004c7048,iVar2);
      uVar6 = 0xffffffff;
      pcVar5 = (char *)(iVar2 + 8);
      do {
        pcVar10 = pcVar5;
        if (uVar6 == 0) break;
        uVar6 = uVar6 - 1;
        pcVar10 = pcVar5 + 1;
        cVar1 = *pcVar5;
        pcVar5 = pcVar10;
      } while (cVar1 != '\0');
      uVar6 = ~uVar6;
      pcVar5 = pcVar10 + -uVar6;
      pcVar10 = local_10;
      for (uVar7 = uVar6 >> 2; uVar7 != 0; uVar7 = uVar7 - 1) {
        *(undefined4 *)pcVar10 = *(undefined4 *)pcVar5;
        pcVar5 = pcVar5 + 4;
        pcVar10 = pcVar10 + 4;
      }
      for (uVar6 = uVar6 & 3; uVar6 != 0; uVar6 = uVar6 - 1) {
        *pcVar10 = *pcVar5;
        pcVar5 = pcVar5 + 1;
        pcVar10 = pcVar10 + 1;
      }
      FUN_00448810((void *)*puVar8,uVar4,uVar4,0);
      FUN_00457e90((void *)*puVar8,1);
      pcVar5 = (char *)FUN_0042a8f0(&DAT_005090b0,*(int *)(iVar3 + 4) + 0x897);
      FUN_00457b80((void *)*puVar8,pcVar5);
    }
    local_c = local_c + 1;
    local_10 = local_10 + 0x20;
    puVar8 = puVar8 + 1;
    if (3 < local_c) {
      return;
    }
  } while( true );
}

