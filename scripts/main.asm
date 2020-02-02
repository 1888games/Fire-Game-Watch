// PET - Commodore PETs
// C64 - Commodore 64
// 264 - C16, C116, Plus4
// VIC - VIC 20

.var target = "C64"
#import "../Lionel/zeroPage.asm"

MAIN: {


#import "../Lionel/lionel.asm"
#import "setup/loadModules.asm"

BASICStub(Entry,"Caveman")

//exomizer sfx sys -t 64 -x "inc $d020" -o yakf.exo yakf.prg
  // 20: Commodore Vic20, unexpanded memory.
  //        23: Commodore Vic20, 3kB memory expansion.
  //        52: Commodore Vic20, 32kB memory expansion.
  //        55: Commodore Vic20  32+3kB memory expansion.
  //        16: Commodore c16
  //         4: Commodore plus4.
  //        64: Commodore c64. (The default target)
  //       128: Commodore c128.
  // 	   4032 :PET

Entry:		
	


	jsr LIONEL.Initialise	

 	jsr C64.BankOutKernalAndBasic
	jsr C64.DisableCIA
	jsr VIC20.ConvertCharacterSet
	jsr VIC20.ConvertTitleSet


	jsr MAPLOADER.Initialise
	jsr TITLE_LOADER.Initialise
	
	jsr SOUND.Initialise

	Set256CharMode264()
	Set24RowMode()
	SetMultiColourMode(1)
	SetVICRows(23)

	jsr SetupScreenMemory

	//jmp LoadGame
	jmp TitleScreen

	//jmp  LoadGame
	


.if(target == "VIC") {

*= $2C00 "Main"

}

PerformFrameCodeFlag: 	.byte $00
GameCounter:			.byte 20, 20, 20 // curr,currMax,Max
GameTickFlag:			.byte $00
GameMode: 				.byte 0
BackgroundColour:		.byte 0
GameIsActive:			.byte 0
InitialCooldown:		.byte 250
GameOverTimer:			.byte 0, 20
GameOver:				.byte 1
LevelCompleteTimer:		.byte 0, 5
WaitingForFire: 		.byte 1
TitleColour:			.byte 0
DeathTimer:				.byte 99, 6




PetLoop:

	jmp PetLoop



TitleScreen: {


	SetBorderColour(0, 5)
	SetBackgroundColour(0,5)
	SetExtendedColour1(7 ,5)  //9
	SetExtendedColour2(0,  5)  //13

	.if (target == "VIC") {
			SetBorderColour(7, 0)
	
	}


	jsr SetupCharMemoryTitle	

	//ClearScreen()

	//jmp PetLoop

	jsr TITLE_LOADER.DrawMap

	//ldy #0
	//jsr SOUND.StartSong	
	
	
	jmp TitleLoop

}





TitleLoop: {

.if (target == "VIC") {
	//	WaitForRasterLine(40)
	}
	.if(target == "C64") {
		//WaitForRasterLine(30,0)
	}

	.if(target == "264" || target == "PET") {
		//WaitForRasterLine(200)
	}


	jsr SOUND.Update

	nop
	bit $00


	ldy #2
	jsr INPUT.ReadJoystick

	.if(target != "PET") {
		
		lda INPUT.FIRE_UP_THIS_FRAME, y
		beq DontStart

		jmp LoadGame

		DontStart:

		lda TitleColour
		beq SetRed

			lda #0
			sta TitleColour

			SetExtendedColour2(0,4)
			jmp TitleLoop

		SetRed:

			lda #2
			sta TitleColour
			SetExtendedColour2(2,4)

		jmp TitleLoop

	}

	else {


		lda INPUT.JOY_LEFT_NOW, y
		bne Amateur

		lda INPUT.JOY_RIGHT_NOW, y
		bne Pro
		
		jmp TitleLoop

		Pro:

			lda #ONE
			sta GameMode
		
			jmp LoadGame

		Amateur:

			lda #ZERO
			sta GameMode
			jmp LoadGame


	}

	jmp TitleLoop

	
}





DeathUpdate:{

		lda DeathTimer + 1
		cmp DeathTimer
		bcc Finish

		dec DeathTimer
		beq NextLife

		//jsr SOUND.SFX_EXPLODE

		jmp Finish

		NextLife:
			jsr MAIN.NextLife

		Finish:

		rts



	}

ColourLastRow: {

	.if(target == "VIC") {
			
		.label COLOR_ADDRESS = VECTOR4
		.label SCREEN_ADDRESS = VECTOR5
		 .label RowOffset = TEMP7
		

		//get row for this position
		ldy #21
		lda VIDEO.ScreenRowLSB, y
	
		// Get CharAddress
		
		sta SCREEN_ADDRESS
		sta COLOR_ADDRESS

		adc #0
		
		lda VIDEO.ScreenRowMSB, y	
		adc #0  // get carry bit from above
		sta RowOffset

		lda SCREEN_RAM + 1
		clc
		adc RowOffset
		sta SCREEN_ADDRESS + 1

		lda COLOR_RAM + 1
		clc
		adc RowOffset
		sta COLOR_ADDRESS +1

		ldy #0
		lda #7

		Loop:	


			
			sta (COLOR_ADDRESS), y

			cpy #12
			bcc NoChange

			lda #4

			NoChange:

			cpy #21
			beq Finish
			iny
			jmp Loop

		Finish:

	}

			rts

}




SetupGameColours: {

		SetBackgroundColour(3 , 4)
		SetExtendedColour1(2 , 3)  //9

		.if (target == "VIC") {
			SetBorderColour(13, 0)
			SetExtendedColour1(8 , 5)  //9
		}

		else {
			SetExtendedColour2(8, 3)  //13
		}

		rts
	

}


SetupScreenMemory: {

	SetC64ScreenMemory($C000)
	SetVICScreenMemory($1000)
	Set264ScreenMemory($1C00)

	rts

}



SetupCharMemory: {
	
		SetC64CharacterMemory($F000)
		SetVICCharacterMemory($1C00)
		Set264CharacterMemory($2800)
	
		

		rts
	

}

SetupCharMemoryTitle: {

		SetC64CharacterMemory($F800)
		Set264CharacterMemory($2000)
		SetVICCharacterMemory($1400)
	
		rts

}



MainIRQ: {

	//inc $d020

	lda #ONE
	sta MAIN.PerformFrameCodeFlag

	lda MAIN.GameIsActive
	beq Paused

	jsr MEN.Control

	Paused:

	jsr MEN.Draw

	clc
	dec MAIN.GameCounter

	bne NotYet


	lda MAIN.GameCounter + 1
	sta MAIN.GameCounter

	asl 

	jsr GameTick

	NotYet:

	//dec $d020

	rts
}



NewGame: {	

	//jmp PetLoop

	//ldx #4
	//jsr CHAR_DRAWING.ColourObject

 	jsr CHAR_DRAWING.ClearAll






 	//jmp PetLoop

	lda #ONE
	//sta LEVELDATA.Ones
	sta GameIsActive

	lda #ZERO
	sta LEVELDATA.NextLevelID
	sta LEVELDATA.Tens
	sta GameOver
//	sta GameIsActive
	
	jsr SCORE.Reset
	jsr LEVELDATA.SetupNextLevel

	jsr Reset

	jsr LIVES.Reset

	lda #ZERO
	sta WaitingForFire

	rts
	
}


NextLife:{

	lda #ONE
	sta GameIsActive

	lda LIVES.Value
	cmp #1
	bcs NotDead

	jsr SetGameOver
	jmp Finish


	NotDead:

	jsr Reset

	Finish:

	rts

}
NextLevel:{	

	lda #ZERO
	sta GameIsActive

	jsr SCORE.LevelComplete


	//ldy #0
	//jsr SOUND.StartSong

	lda LevelCompleteTimer + 1
	sta LevelCompleteTimer



	rts
}

GotoNextLevel: {

	jsr Reset
	jsr LEVELDATA.SetupNextLevel

	


	lda #ONE
	sta GameIsActive

		

	rts


}

CheckNextLevel:{

	lda LevelCompleteTimer
	beq Finish

	dec LevelCompleteTimer
	bne Finish

	jsr GotoNextLevel

	Finish:
		rts

}

Random:{


	rts
}


Reset:{

		SetBorderColour(0 , 5)

		jsr JUMPERS.Reset


		
		rts

}


LoadGame: {

	ClearScreen()
	jsr SetupGameColours
	jsr SetupCharMemory


	
	jsr MAPLOADER.DrawMap
	
	jsr NewGame


	jmp Loop

}






TempLoop: {

	WaitForRasterLine(0, 0)

	jsr SOUND.Update

	jmp TempLoop
}





CheckWhetherToUpdateScore: {

		//lda ZP_COUNTER
		//and #1
		//bne NoScoreAdd

		jsr SCORE.CheckScoreToAdd

		NoScoreAdd:
			rts
}




SetGameOver:{

	lda #ZERO
	sta GameIsActive

	lda #ONE
	sta GameOver

	lda GameOverTimer+1
	sta GameOverTimer
	
	rts

}



DrawBackground: {

	.if(target == "C64") {

		WaitForRasterLine(52, 0)

		nop
		nop
		nop
		nop
		nop
		nop
		nop
		
		SetBackgroundColour(3,5)

		jsr SOUND.Update

		WaitForRasterLine(134, 0)


		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		
		SetBackgroundColour(5, 5)
		jsr FrameCode

		WaitForRasterLine(187, 0)
		SetBackgroundColour(7, 5)



	}



	.if(target == "264") {

		 WaitForRasterLine(10, 0)

		// nop
		// nop
		// nop
		// nop
		// nop
		// nop
		// nop
		
		 SetBackgroundColour(3,5)

		jsr SOUND.Update

		 WaitForRasterLine(88, 0)

		// nop
		// nop
		// nop
		// nop
		// nop
		// nop
		// nop
		// nop
		// nop
		
		 SetBackgroundColour(5, 5)
		jsr FrameCode

		WaitForRasterLine(138, 0)
		SetBackgroundColour(7, 5)

		//SetBackgroundColour(3,5)


	}

	rts


}


Loop:

	jsr DrawBackground



	.if (target == "C64") {
		WaitForRasterLine(190, 0)
	}

	.if(target == "264") {
		WaitForRasterLine(142, 0)
	}


	jsr JUMPERS.CheckDrawing

	
	jsr MainIRQ
	


	jmp Loop
	

GameOverUpdate: {

	lda GameOver
	bne Continue

	jmp Loop

	Continue:

	lda GameOverTimer
	cmp #1
	bcs Waiting

	jmp Loop


	Waiting:

	dec GameOverTimer
	jmp Loop

}


FrameCode: {

		
		lda GameIsActive
		beq GamePaused

		inc ZP_COUNTER
		inc RANDOM.RandomAdd
		
		jsr FIRE.UpdateFire
		
		//jsr CAVEMAN.CheckKilledByDino

		GamePaused:

			jsr CheckWhetherToUpdateScore
			

			lda GameOver
			beq Finish

			lda GameOverTimer
			bne Finish

			ldx #46
			ldy #ONE
			jsr CHAR_DRAWING.ColourObject

			lda INPUT.FIRE_UP_THIS_FRAME
			bne Finish

			jmp TitleScreen


			Finish:
				rts

	

}	



GameTick: {

		//.break

		lda GameIsActive
		beq NotRunning

		jsr FIRE.Update
		jsr JUMPERS.Update

		jmp Finish

		NotRunning:

			jsr CheckNextLevel
			jsr DeathUpdate
			jmp GameOverUpdate


	

		Finish:
		
		rts
}


#import "setup/assets.asm"


}