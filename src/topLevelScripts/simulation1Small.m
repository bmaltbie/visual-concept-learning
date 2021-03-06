function universalSimulation(pHandle)
% universalSimulation(pHandle)
%
% Josh Rule <rule@mit.edu>, December 2014
% run the C2 simulations to test our universal patches
%
% pHandle, function handle, function loading the parameters
    p = pHandle();
    fprintf('Params Initialized\n\n');

    addpath(genpath(p.srcPath));
    fprintf('Source Loaded\n\n');

    rng(p.seed,'twister');
    fprintf('Pseudorandom Number Generator Reset\n\n');

    [animalImgFiles,noAnimalImgFiles] = getAnAImgFiles(p.imgDir);
    fprintf('Image Lists Created\n\n');

    for iSet = 1:length(p.c2PatchSets)

        patchSet = p.c2PatchSets{iSet};
        cacheAnAC2(p.caching,patchSet);
        fprintf('%s C2 Caching Complete\n\n',patchSet);

        c2Files = strcat(p.caching.cacheDir,{'animals.','noAnimals.'}, ...
                         patchSet,'.c2.mat');

        if ismember(patchSet,p.c3PatchSets)

            organicC3Files = universalC3Helper(p,c2Files,patchSet,'organic');
            inorganicC3Files = universalC3Helper(p,c2Files,patchSet,'inorganic');
            evaluateFeatureSets(p,c2Files,organicC3Files,inorganicC3Files);

        else

            evaluateFeatureSets(p,c2Files);

        end

        fprintf('%s Evaluation Complete\n\n', patchSet);

    end

    evaluateClassSpecific(p); % includes caching

end

function c3Files = universalC3Helper(p,c2Files,patchSet,type)
    c3Files = strcat(p.caching.cacheDir,{'animals.','noAnimals.'}, ...
      patchSet,'-',type,'.c3.mat');
    c3Dir = ensureDir([p.patchDir patchSet '-' type 'C3vLinear/']);
    cacheC3Wrapper(c3Files,c2Files,c3Dir);
    fprintf('%s %s C3 Caching Complete\n\n',patchSet,type);
end

function [animalImgFiles,noAnimalImgFiles] = getAnAImgFiles(imgDir)
    animalDir = [imgDir 'animals/'];
    animals = dir([animalDir '*.jpg']);
    animalImgFiles = strcat(animalDir,{animals.name});

    noAnimalDir = [imgDir 'noAnimals/'];
    noAnimals = dir([noAnimalDir '*.jpg']);
    noAnimalImgFiles = strcat(noAnimalDir,{noAnimals.name});
end

function cacheAnAC2(p,patchSet)
    patchFile = [p.patchDir patchSet '.xml'];
    animalFile = [p.cacheDir 'animals.' patchSet '.c2.mat'];
    if ~exist(animalFile,'file')
        cacheC2(animalFile,patchFile,p.maxSize,animalImgs,p.hmaxHome);
    end
    noAnimalFile = [p.cacheDir 'noAnimals.' patchSet '.c2.mat'];
    if ~exist(noAnimalFile,'file')
        cacheC2(noAnimalFile,patchFile,p.maxSize,noAnimalImgs,p.hmaxHome);
    end
end

function evaluateClassSpecific(p)
    % class-specific
    outFile = [p.outDir 'class-specific-evaluation.mat'];
    outFileCombined = [p.outDir 'class-specific-and-kmeans-evaluation.mat'];
    animalFile = [p.caching.cacheDir 'animals.kmeans.c2.mat'];
    noAnimalFile = [p.caching.cacheDir 'noAnimals.kmeans.c2.mat'];
    [kmeansC2,labels] = buildC2({animalFile,noAnimalFile});
    load([p.outDir 'splits.mat'],'cvsplit');
    if ~exist(outFile,'file')
        aucs    =  nan(size(labels,1),length(p.nTrainingExamples),p.nRuns);
        dprimes =  nan(size(labels,1),length(p.nTrainingExamples),p.nRuns);
        models  = cell(size(labels,1),length(p.nTrainingExamples),p.nRuns);
        aucs2    =  nan(size(labels,1),length(p.nTrainingExamples),p.nRuns);
        dprimes2 =  nan(size(labels,1),length(p.nTrainingExamples),p.nRuns);
        models2  = cell(size(labels,1),length(p.nTrainingExamples),p.nRuns);
        if ~exist([p.outDir 'classSpecificSplits.mat'],'file')
            for iClass = 1:size(labels,1)
                for iRun = 1:p.nRuns
                    for iTrain = find(p.nTrainingExamples > 128)
                        classLabels = labels(iClass,:);
                        patchTrainSplit(iClass,iTrain,iRun) = cv(...
                          classLabels(cvsplit{iClass,iTrain,iRun}),128,1);
                    end
                end
            end
            save([p.outDir 'classSpecificSplits.mat'],'patchTrainSplit');
        else
            load([p.outDir 'classSpecificSplits.mat'],'patchTrainSplit');
        end
        for iClass = 1:size(labels,1)
            for iRun = 1:p.nRuns
                for iTrain = find(p.nTrainingExamples > 128)
                    patchName = ['classSpecific' num2str(iTrain) 'Run' num2str(iRun)];
                    patchSizes = [2:2:16; 2:2:16; 4.*ones(1,8); 1600.*ones(1,8)]; 
                    animals = load([p.c2CacheDir 'animals.kmeans.c2.mat'],'imgFiles','maxSize');
                    noAnimals = load([p.c2CacheDir 'noAnimals.kmeans.c2.mat'],'imgFiles','maxSize');
                    % create and save the raw patch set
                    if ~exist([p.patchDir patchName '.original.mat'],'file')
                        completeFiles = {animals.imgFiles{:} noAnimals.imgFiles{:}};
                        potentialFiles = completeFiles(cvsplit{iClass,iTrain,iRun});
                        files = potentialFiles(patchTrainSplit{iClass,iTrain,iRun});
                        load([p.home 'gabor-and-c1.mat'],'filters','filterSizes','c1Scale', ...
                          'c1Space','c1OL');
                        params.maxSize = animals.maxSize;
                        params.filters = filters;
                        params.c1Scale = c1Scale;
                        params.c1Space = c1Space;
                        params.c1OL    = c1OL;
                        params.filterSizes = filterSizes;
                        c1r = c1rFromCells(files,params);
                        fprintf('c1: %d %d\n',size(c1r));
                        ps = extractedPatches(c1r,patchSizes,0.4,0.8);
                        save([p.patchDir patchName '.original.mat'],'ps');
                        fprintf('raw extraction complete\n');
                    else
                        load([p.patchDir patchName '.original.mat'],'ps');
                    end
                    % create and save the clustered class-specific patches
                    if ~exist([p.patchDir patchName '.xml'],'file')
                        load([p.home 'gabor-and-c1.mat'],'filters','filterSizes','c1Scale', ...
                          'c1Space','c1OL');
                        patches = universalPatches(ps.patches,400);
                        patchFile = matlabPatches2OCVPatches(filters,filterSizes,c1Scale, ...
                          c1Space,c1OL,patches,patchSizes,patchName,p.patchDir);
                        fprintf('clustering complete\n');
                    else
                        patchFile = [p.patchDir patchName '.xml'];
                    end
                    % cache the activations
                    animalFile = [p.c2CacheDir 'animals.' patchName '.c2.mat'];
                    cacheC2(animalFile,patchFile,animals.maxSize,animals.imgFiles,p.caching.hmaxHome);
                    noAnimalFile = [p.c2CacheDir 'noAnimals.' patchName '.c2.mat'];
                    cacheC2(noAnimalFile,patchFile,noAnimals.maxSize,noAnimals.imgFiles,p.caching.hmaxHome);
                    fprintf('caching complete\n');
                    % load the necessaries
                    [completeC2,labels2] = buildC2({animalFile,noAnimalFile});
                    assert(isequal(labels(:),labels2(:)),'labels do not match\n');
                    combinedC2 = [kmeansC2; completeC2];
                    testNums = find(~cvsplit{iClass,iTrain,iRun});
                    patchTrainNums = find(cvsplit{iClass,iTrain,iRun});
                    patchNums = patchTrainNums(patchTrainSplit{iClass,iTrain,iRun} == 1);
                    trainNums = patchTrainNums(patchTrainSplit{iClass,iTrain,iRun} == 0);
                    evalNums = sort([testNums trainNums],'ascend');
                    c2{iClass,iTrain,iRun} = completeC2(:,evalNums); % strip out patch images
                    c22{iClass,iTrain,iRun} = combinedC2(:,evalNums);
                    classLabels = labels(iClass,:);

                    [aucs(iClass,iTrain,iRun),dprimes(iClass,iTrain,iRun),models{iClass,iTrain,iRun}] = ...
                      evaluatePerformance(c2{iClass,iTrain,iRun},classLabels(evalNums),...
                      {cvsplit{iClass,iTrain,iRun}(evalNums)},p.method,p.options,size(c2{iClass,iTrain,iRun},1),[]);
                    
                    [aucs2(iClass,iTrain,iRun),dprimes2(iClass,iTrain,iRun),models2{iClass,iTrain,iRun}] = ...
                      evaluatePerformance(c22{iClass,iTrain,iRun},classLabels(evalNums),...
                      {cvsplit{iClass,iTrain,iRun}(evalNums)},p.method,p.options,size(c22{iClass,iTrain,iRun},1),[]);
                    fprintf('class-specific run %d\n',iRun);
                end
            end
        end
        save(outFile,'labels','c2','aucs','dprimes', 'models','-v7.3');
        clear animals noAnimals c2 aucs dprimes models outFile;
        aucs = aucs2;
        models = models2;
        dprimes = dprimes2;
        c2 = c22;
        save(outFileCombined,'labels','aucs','dprimes','c2','models','-v7.3');
    end
    fprintf('class-specific fully evaluated\n');
end
