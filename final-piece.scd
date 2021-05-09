(
s.freeAll;
s.reboot;
s.waitForBoot{
	//load the file kinect code
	"kinect-receiver.scd".resolveRelative.load;

	//load code from beginning of the piece
	"granular-beginning.scd".resolveRelative.load;
	//start with zero people
	~previousPerson = 0;

	//how long to record performance after detectin person, low and high limits.
	~recordingTime = {rrand(10, 20)};



	SynthDef(\recorder, { arg out = 0, bufnum, run = 0, gate = 1;
		var input;
		input = SoundIn.ar(0) *Linen.kr(gate, doneAction:2);
		RecordBuf.ar(input, bufnum, doneAction:2, run:1, loop:0);
	}).add;



	~complexResFunc = {
		|in, mixMod, modSpeed= 200, modLoRange=200, modHiMul= 2, resonanceDecay=0.1|
		XFade2.ar(
			in,
			ComplexRes.ar(
				in,
				SinOsc.kr(modSpeed).range(modLoRange, modLoRange*modHiMul),
				resonanceDecay),
			mixMod)};

	~harmProxy = NodeProxy.audio(s, 2).play;
	~harmProxy.fadeTime=5;
	~percProxy = NodeProxy.audio(s, 2).play;
	~percProxy.fadeTime=5;

	~processFunc = {
		{
			1.do{

				~oboeBuf = Buffer.alloc(s, s.sampleRate*120, 1);
				//start recording and restart bufers
				~harmBuf = Buffer.new(s);
				~percBuf = Buffer.new(s);
				e = Buffer.new(s);
				a=Synth(\recorder, [\bufnum, ~oboeBuf]);

				///////////////////////////////////////////////////////////////////////////////////////
				//This is the total time it will record the oboe performance before processing!!!!!1
				///////////////////////////////////////////////////////////////////////////////////////
				~recordingTime.value.wait;


				a.release;

				2.wait;

				//process the recording
				Routine{
					t = Main.elapsedTime;
					FluidBufHPSS.process(s, ~oboeBuf, harmonic: ~harmBuf, percussive: ~percBuf).wait;
					(Main.elapsedTime - t).postln;
				}.play;

				2.wait;

				~harmBuf.query;
				~percBuf.query;

				1.wait;

				~harmSliceBuf = Buffer.new(s);
				~percSliceBuf = Buffer.new(s);



				//slice harmonic sounds
				Routine{
					t = Main.elapsedTime;
					FluidBufNoveltySlice.process(s,~harmBuf, indices: ~harmSliceBuf, threshold:0.4,filterSize: 1, minSliceLength: 32).wait;
					(Main.elapsedTime - t).postln;
				}.play;


				//slice percusive sounds
				Routine{
					t = Main.elapsedTime;
					FluidBufNoveltySlice.process(s,~percBuf, indices: ~percSliceBuf, threshold:0.4,filterSize: 1, minSliceLength: 32).wait;
					(Main.elapsedTime - t).postln;
				}.play;

				1.wait;

				//check the number of slices: it is the number of frames in the transBuf minus the boundary index.
				~harmSliceBuf.query;
				~percSliceBuf.query;

				0.5.wait;

				//start playing the sounds
				~playerFunc.value;




			}
		}.fork
	};

	~playerFunc = {

		~harmProxy.source ={
			|noiseSpd =1, amp =1, rate=1|

			BufRd.ar(1, ~harmBuf,
				Phasor.ar(0,rate.lag(0.1),
					start: BufRd.kr(1, ~harmSliceBuf,
						LFNoise0.kr(noiseSpd).range(0, BufFrames.kr(~harmSliceBuf) -noiseSpd), 0, 2),
					end: BufRd.kr(1, ~harmSliceBuf,
						LFNoise0.kr(noiseSpd).range(1, BufFrames.kr(~harmSliceBuf)), 0, 2),
					resetPos: BufRd.kr(1,~harmSliceBuf,
						LFNoise0.kr(noiseSpd).range(0, BufFrames.kr(~harmSliceBuf) - 1), 0, 1)),
				0,
				2) * amp;
		};

		~harmProxy[10] = \filter -> {|in, pan=0| Splay.ar(in, 0, 1, pan)};



		~harmProxy[15] = \filter -> {|in, mix=0, delayTime=0.2, decayTime=1| CombC.ar(in, 1, delayTime.lag(0.1), decayTime)};

		~harmProxy[20] = \filter -> {|in, cutoffFreq=5000, rq=1| RLPF.ar(in, cutoffFreq, rq)};

		~harmProxy[25]= \filter -> ~complexResFunc;

		~harmProxy[30] = \filter -> {|in, mix=0| FreeVerb.ar(in, mix, 1, 0)};

		~harmProxy[100] = \filter -> {|in| Limiter.ar(in, 0.9)};




		~percProxy.source ={
			|noiseSpd =1, amp =1, rate=1|

			BufRd.ar(1, ~percBuf,
				Phasor.ar(0,1.lag(0.1),
					start: BufRd.kr(1, ~percSliceBuf,
						LFNoise0.kr(noiseSpd).range(0, BufFrames.kr(~percSliceBuf) -1), 0, 2),
					end: BufRd.kr(1, ~percSliceBuf,
						LFNoise0.kr(noiseSpd).range(1, BufFrames.kr(~percSliceBuf)), 0, 2),
					resetPos: BufRd.kr(1,~percSliceBuf,
						LFNoise0.kr(noiseSpd).range(0, BufFrames.kr(~percSliceBuf) - 1), 0, 1)),
				0,
				2) * amp;
		};

		~percProxy[10] = \filter -> {|in, pan=0| Splay.ar(in, 0, 1, pan)};


		~percProxy[15] = \filter -> {|in, mix=0, delayTime=0.2, decayTime=1| CombC.ar(in, 1, delayTime.lag(0.1), decayTime)};

		~percProxy[20] = \filter -> {|in, cutoffFreq=5000, rq=1| RLPF.ar(in, cutoffFreq, rq)};

		~percProxy[25]= \filter -> ~complexResFunc;

		~percProxy[30] = \filter -> {|in, mix=0| FreeVerb.ar(in, mix, 1, 0)};

		~percProxy[100] = \filter -> {|in| Limiter.ar(in, 0.9)};


		Tdef(\interaction).play;
	};


	{
		inf.do{
			|i|

			//if one person appears
			case
			{(~people ==1) && (~previousPerson == 0)}
			//this will start the process of recording and processing the sound
			{
				//stop playing beginning of the piece
				Tdef(\playGran).stop;
				~granGrp.set(\gate, 0);

				//start second part, processing sounds
				~processFunc.value;

				//print to GUI
				{~infoText.string= "person detected"}.defer;



			}

			//if it disappears from range
			{(~people ==0) && (~previousPerson == 1)}
			//tstop proxys
			{[~harmProxy, ~percProxy].collect({ |i| i.source = nil});

				{~infoText.string= "person out of range"}.defer;

				Tdef(\interaction).stop;
				//go back to beginning
				Tdef(\playGran).play

			};

			~previousPerson = ~people;
			1.wait;
		}
	}.fork;

};




(
Window.closeAll;

~window = Window.new("Piece", 500@400);

~guiButton = Button(~window, Rect(60, 20, 340, 200))
.states_([
	["finish", Color.black, Color.red],
	["Finish", Color.white, Color.white]
])
.action_({ arg butt;
	switch(butt.value,

		1, {
			Tdef(\playGran).stop;
			~granGrp.set(\gate, 0);

			[~harmProxy, ~percProxy].collect({ |i| i.source = nil});

			Tdef(\interaction).stop;
	})
})
.font_(Font("Helvetica", 50));

~infoText = StaticText(~window, Rect(20, 150, 450, 350))
.string_("hi")
.font_(Font("Helvetica", 50));
~window.front;
)
)
