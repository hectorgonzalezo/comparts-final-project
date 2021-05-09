   b = Buffer.alloc(s, s.sampleRate * 5, 1);

	~micBus = Bus.audio(s,1);
	~ptrBus = Bus.audio(s,1);


	//SynthDefs based on Eli Fieldsteel real time granulator:
	// https://github.com/elifieldsteel/SuperCollider-Tutorials/blob/master/full%20video%20scripts/26_script.scd

	SynthDef(\mic, {
		arg in=0, out=0, amp=1;
		var sig;
		sig = SoundIn.ar(in) * amp;
		Out.ar(out, sig);
	}).add;


	SynthDef(\ptr, {
		arg out=0, buf=0, rate =1;
		var sig;
		sig = Phasor.ar(0, BufRateScale.kr(buf)*rate, 0, BufFrames.kr(buf));
		Out.ar(out, sig);
	}).add;

	SynthDef(\rec, {
		arg ptrIn=0, micIn=0, buf=0;
		var ptr, sig;
		ptr = In.ar(ptrIn, 1);
		sig = In.ar(micIn, 1);
		BufWr.ar(sig, buf, ptr);
	}).add;




	SynthDef(\player, { |volIn= 0.2, fadeT =5, gateWhich=0, dens=20, baseDur=0.1, durRand=1, buf=0,
		rate=1, pos=0,
		grainEnv=(-1), sync= 1, pan=0, panRand=0, rateRand =1, gate=1, atk=1, rel=1, amp1=0.5, amp2=0.5, vol=1, out=0, ptrBus=0, ptrSampleDelay=20000, ptrRandSamples=5000, minPtrDelay=1000, fadeCurve = (-3), ptrRandSpeed=100|

		var sig, env, densCtrl, rateCtrl, posCtrl, panCtrl, ptr, ptrRand, totalDelay, durCtrl, maxGrainDur, sig1, player, which;



		env = EnvGen.kr(Env.asr(atk,1,rel), gate, doneAction:2);

		densCtrl = Select.ar(sync, [Dust.ar(dens), Impulse.ar(dens)]); //para seleccionar si la densidad es fija o aleatoria

		durCtrl = baseDur * LFNoise1.ar(100).exprange(1/durRand, durRand);

		rateCtrl = rate * LFNoise1.ar(100).exprange(1/rateRand, rateRand);

		panCtrl = pan + LFNoise1.kr(100).bipolar(panRand);

		ptrRand = LFNoise1.ar(ptrRandSpeed).bipolar(ptrRandSamples);

		totalDelay = max(ptrSampleDelay  - ptrRand, minPtrDelay);

		ptr = In.ar(ptrBus, 1);
		ptr = ptr - ptrSampleDelay;
		ptr = ptr / BufFrames.kr(buf);

		maxGrainDur = (totalDelay / rateCtrl) / SampleRate.ir;
		durCtrl = min(durCtrl , maxGrainDur);


		sig = GrainBuf.ar(
			2,
			densCtrl,
			durCtrl,
			buf,
			rateCtrl,
			ptr,
			2,
			panCtrl,
			grainEnv
		);

		sig1 = Splay.ar(SoundIn.ar(0)*volIn);


		which = EnvGen.kr(Env.asr(fadeT,0.9, fadeT, fadeCurve), gateWhich);

		player = XFade2.ar(sig1 * amp1, sig* amp2, which*2-1);

		Out.ar(Limiter.ar(out, 0.9), player * env * vol)
	}).add;


	~micGrp = Group.new;
	~ptrGrp = Group.after(~micGrp);
	~recGrp = Group.after(~ptrGrp);
	~granGrp = Group.after(~recGrp);


	Synth(\mic, [\in, 0, \out, ~micBus], ~micGrp);
	Synth(\ptr, [\buf, b, \out, ~ptrBus],~ptrGrp);
	Synth(\rec, [\ptrIn, ~ptrBus, \micIn, ~micBus, \buf, b], ~recGrp);


	s.sync;





	Tdef(\playGran,{
	//plays 5 instances of the Synth, these are the main sounds
8.collect({
		arg n;

			~sounds = Array.newClear(8);

		~sounds[n] =Synth(\player, [
			\amp, 1/24,
			\amp2, 0.5,
			\buf, b,
			\out, 0,
			\atk, 1,
			\rel, 10,
			\gate, 1,
			\sync, [0,1].wchoose([0.2, 0.8]),
			\dens, exprand(5,100),
			\baseDur, 0.05,
			\durRand, 1.5,
			\rate, ((0..12)*([-1,1].wchoose([0.7, 0.3]))).choose.midiratio,
			\rateRand, 1.midiratio,
			\pan, rrand(-0.5, 0.5),
			\panRand, 0.5,
			\grainEnv, -1,
			\ptrBus, ~ptrBus,
			\ptrSampleDelay, n.linlin(0,8,1000,s.sampleRate*1) * rrand(0.8, 1.2),
			\ptrRandSpeed, 10,
			\ptrRandSamples, 1000,
			\minPtrDelay, 1000,

			\fadeT, rrand(1.0, 5.0),
			\fadeCurve, rrand(-2.0, -3.0),

			\gateWhich, 1
		], ~granGrp
		);
	});

		rrand(10,20).wait;
		inf.do{

			//randomize arguments of granular sounds every x seconds
		~sounds.collect({|synth, n| synth.set(\amp, 1/16,

			\sync, [0,1].wchoose([0.2, 0.8]),
			\dens, exprand(5,100),
	\rate, ((0..12)*([-1,1].wchoose([0.7, 0.3]))).choose.midiratio,
			\rateRand, 1.midiratio,
			\pan, rrand(-0.5, 0.5),
			\ptrSampleDelay, n.linlin(0,8,1000,s.sampleRate*(rrand(0.5,2))) * rrand(0.8,1.2),
			\ptrRandSpeed, 10,
			\ptrRandSamples, 1000,
			\minPtrDelay, 1000,

			\fadeT, rrand(1.0, 5.0),
	\fadeCurve, rrand(-2.0, -3.0))});

			rrand(10, 25).wait;


		}
	}).play