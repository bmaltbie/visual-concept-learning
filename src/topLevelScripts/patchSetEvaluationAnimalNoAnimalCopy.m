home = '/home/josh/data/ruleRiesenhuber2013/';
addpath(genpath([home 'src/']));

imgDir = [home 'imageSets/animalNoAnimal/'];
outDir = ensureDir([home 'evaluation/animalNoAnimal/']);
patchDir = [home 'patchSets/'];
hmaxHome = [home 'src/hmax-ocv/'];

method = 'svm';
options = '-s 0 -t 0 -b 1 -q -c 0.1';
labels = [ones(1,600) zeros(1,600)];

if ~exist([outDir 'splits.mat'],'file')
    nTrainingExamples = [16 32 64 128 256 512 600 1024];
    nPatchExamples = 128;
    nRuns = 40;
    patchPerfSplit = cv(labels,nPatchExamples,nRuns);
    for iClass = 1:size(labels,1)
        for iRun = 1:nRuns
            cvsplit(iClass,:,iRun) = cv(...
              labels(~patchPerfSplit{iClass,1,iRun}),nTrainingExamples,1);
        end
    end
    save([outDir 'splits.mat'],'nTrainingExamples','nRuns','cvsplit','patchPerfSplit');
    fprintf('splits generated\n');
else
    load([outDir 'splits.mat'])
    fprintf('splits loaded\n');
end

% class-specific
outFile = [outDir 'class-specific-evaluation.mat'];
if ~exist(outFile,'file')
    aucs = nan(size(labels,1),length(nTrainingExamples),nRuns);
    dprimes  = nan(size(labels,1),length(nTrainingExamples),nRuns);
    models = cell(size(labels,1),length(nTrainingExamples),nRuns);
    for iClass = 1:size(labels,1)
        for iRun = 1:nRuns
            % create the patch set
            animals = load([imgDir 'c2Cache/animals.kmeans.c2.mat'], 'imgFiles','maxSize');
            noAnimals = load([imgDir 'c2Cache/noAnimals.kmeans.c2.mat'], 'imgFiles','maxSize');
            completeFiles = {animals.imgFiles{:} noAnimals.imgFiles{:}};
            files = completeFiles(~patchPerfSplit{iClass,1,iRun});
            patchSizes = [2:2:16; 2:2:16; 4.*ones(1,8); 1600.*ones(1,8)]; 
            load([home 'gabor-and-c1.mat'],'filters','filterSizes','c1Scale', ...
              'c1Space','c1OL');
            params.maxSize = animals.maxSize;
            params.filters = filters;
            params.c1Scale = c1Scale;
            params.c1Space = c1Space;
            params.c1OL    = c1OL;
            params.filterSizes = filterSizes;
            c1r = c1rFromCells(files,params);
            fprintf('c1\n');
            ps = extractedPatches(c1r,patchSizes,0.4,0.8);
            fprintf('extracted\n');
            patches = universalPatches(ps.patches,400);
            fprintf('kmeans\n');
            % save the patches
            patchName = ['classSpecific' num2str(iRun)];
	    save([patchDir patchName '.original.mat'],'ps');
            patchFile = matlabPatches2OCVPatches(filters,filterSizes,c1Scale, ...
              c1Space,c1OL,patches,patchSizes,patchName,patchDir);
            fprintf('saved\n');
            % cache the activations
            animalFile = [imgDir 'c2Cache/animals.' patchName '.c2.mat'];
            cacheC2(animalFile,patchFile,animals.maxSize,animals.imgFiles,hmaxHome);
            noAnimalFile = [imgDir 'c2Cache/noAnimals.' patchName '.c2.mat'];
            cacheC2(noAnimalFile,patchFile,noAnimals.maxSize,noAnimals.imgFiles,hmaxHome);
            fprintf('cached\n');
            % load the necessaries
            animals = load(animalFile,'c2');
            noAnimals = load(noAnimalFile,'c2');
            completeC2 = [animals.c2 noAnimals.c2];
            c2{iRun} = completeC2(~patchPerfSplit{iClass,1,iRun},:);
            [aucs(iClass,:,iRun),dprimes(iClass,:,iRun),models(iClass,:,iRun)] = ...
              evaluatePerformance(c2{iRun},...
              labels(~patchPerfSplit{iClass,1,iRun}),...
              cvsplit(iClass,:,iRun),method,options,size(c2{iRun},1),[]);
            fprintf('class-specific run %d\n',iRun);
        end
    end
    save(outFile,'labels','c2','aucs','dprimes', 'models','-v7.3');
    clear animals noAnimals c2 aucs dprimes models outFile;
end
fprintf('class-specific fully evaluated\n');

type0 = {'kmeans','random','random23'};
% k-means 400
for i = 1:length(type0)
    outFile = [outDir type0{i} '-evaluation.mat'];
    if ~exist(outFile,'file')
        aucs = nan(size(labels,1),length(nTrainingExamples),nRuns);
        dprimes  = nan(size(labels,1),length(nTrainingExamples),nRuns);
        models = cell(size(labels,1),length(nTrainingExamples),nRuns);
        animals = load([imgDir 'c2Cache/animals.' type0{i} '.c2.mat'], 'c2');
        noAnimals = load([imgDir 'c2Cache/noAnimals.' type0{i} '.c2.mat'], 'c2');
        completeC2 = [animals.c2 noAnimals.c2];
        for iClass = 1:size(labels,1)
            for iRun = 1:nRuns
                c2{iRun} = completeC2(~patchPerfSplit{iClass,1,iRun},:);
                [aucs(iClass,:,iRun),dprimes(iClass,:,iRun),models(iClass,:,iRun)] = ...
                  evaluatePerformance(c2{iRun},...
                  labels(~patchPerfSplit{iClass,1,iRun}),...
                  cvsplit(iClass,:,iRun),method,options,size(c2{iRun},1),[]);
            end
        end
        save(outFile,'labels','c2','aucs','dprimes', 'models','-v7.3');
        clear animals noAnimals c2 aucs dprimes models outFile;
    end
    fprintf('%s evaluated\n',type0{i});
end

% type1 = {'organic','inorganic'};
% type2 = {'isolated','shared'};
% for j = 1:length(type2)
%     for i = 1:length(type1)
%         % single patch type
%         outFile = [outDir type1{i} '-' type2{j} '-evaluation.mat'];
%         if ~exist(outFile,'file')
%             aucs = nan(size(labels,1),length(nTrainingExamples),nRuns);
%             dprimes  = nan(size(labels,1),length(nTrainingExamples),nRuns);
%             models = cell(size(labels,1),length(nTrainingExamples),nRuns);
%             animals = load([imgDir 'c2Cache/animals.' type1{i} '.' type2{j} '.c3.mat'], 'c3');
%             noAnimals = load([imgDir 'c2Cache/noAnimals.' type1{i} '.' type2{j} '.c3.mat'], 'c3');
%             completeC3 = [animals.c3 noAnimals.c3];
%             for iClass = 1:size(labels,1)
%                 for iRun = 1:nRuns
%                     c3{iRun} = completeC3(~patchPerfSplit{iClass,1,iRun},:);
%                     [aucs(iClass,:,iRun),dprimes(iClass,:,iRun),models(iClass,:,iRun)] = ...
%                       evaluatePerformance(c3{iRun},...
%                       labels(~patchPerfSplit{iClass,1,iRun}),...
%                       cvsplit(iClass,:,iRun),method,options,size(c3{iRun},1),[]);
%                 end
%             end
%             save(outFile,'labels','c3','aucs','dprimes', 'models','-v7.3');
%             clear animals noAnimals c3 aucs dprimes models outFile;
%         end
%         fprintf('%s - %s evaluated\n',type1{i},type2{j});
%         % combined patch types
%         outFile = [outDir type1{i} '-' type2{j} '-plus-kmeans-evaluation.mat'];
%         if ~exist(outFile,'file')
%             aucs = nan(size(labels,1),length(nTrainingExamples),nRuns);
%             dprimes  = nan(size(labels,1),length(nTrainingExamples),nRuns);
%             models = cell(size(labels,1),length(nTrainingExamples),nRuns);
%             c2Animals = load([imgDir 'c2Cache/animals.kmeans.c2.mat'], 'c2');
%             c2NoAnimals = load([imgDir 'c2Cache/noAnimals.kmeans.c2.mat'], 'c2');
%             c3Animals = load([imgDir 'c2Cache/animals.' type1{i} '.' type2{j} '.c3.mat'], 'c3');
%             c3NoAnimals = load([imgDir 'c2Cache/noAnimals.' type1{i} '.' type2{j} '.c3.mat'], 'c3');
%             completeC2C3 = [c2Animals.c2 c2NoAnimals.c2; c3Animals.c3 c3NoAnimals.c3];
%             for iClass = 1:size(labels,1)
%                 for iRun = 1:nRuns
%                     c2c3{iRun} = completeC2C3(~patchPerfSplit{iClass,1,iRun},:);
%                     [aucs(iClass,:,iRun),dprimes(iClass,:,iRun),models(iClass,:,iRun)] = ...
%                       evaluatePerformance(c2c3{iRun},...
%                       labels(~patchPerfSplit{iClass,1,iRun}),...
%                       cvsplit(iClass,:,iRun),method,options,size(c2c3{iRun},1),[]);
%                 end
%             end
%             save(outFile,'labels','c2c3','aucs','dprimes', 'models','-v7.3');
%             clear animals noAnimals c2c3 aucs dprimes models outFile;
%         end
%         fprintf('%s - %s + k-means evaluated\n',type1{i},type2{j});
%     end
%     % Organic + Inorganic C3
%     outFile = [outDir type2{j} '-all-C3-evaluation.mat'];
%     if ~exist(outFile,'file')
%         aucs = nan(size(labels,1),length(nTrainingExamples),nRuns);
%         dprimes  = nan(size(labels,1),length(nTrainingExamples),nRuns);
%         models = cell(size(labels,1),length(nTrainingExamples),nRuns);
%         animalsOrganic = load([imgDir 'c2Cache/animals.organic.' type2{j} '.c3.mat'], 'c3');
%         animalsInorganic = load([imgDir 'c2Cache/animals.inorganic.' type2{j} '.c3.mat'], 'c3');
%         noAnimalsOrganic = load([imgDir 'c2Cache/noAnimals.organic.' type2{j} '.c3.mat'], 'c3');
%         noAnimalsInorganic = load([imgDir 'c2Cache/noAnimals.inorganic.' type2{j} '.c3.mat'], 'c3');
%         completeC3 = [animalsOrganic.c3   noAnimalsOrganic.c3; ...
%                       animalsInorganic.c3 noAnimalsInorganic.c3];
%         for iClass = 1:size(labels,1)
%             for iRun = 1:nRuns
%                 c3{iRun} = completeC3(~patchPerfSplit{iClass,1,iRun},:);
%                 [aucs(iClass,:,iRun),dprimes(iClass,:,iRun),models(iClass,:,iRun)] = ...
%                   evaluatePerformance(c3{iRun},...
%                   labels(~patchPerfSplit{iClass,1,iRun}),...
%                   cvsplit(iClass,:,iRun),method,options,size(c3{iRun},1),[]);
%             end
%         end
%         save(outFile,'labels','c3','aucs','dprimes', 'models','-v7.3');
%         clear animals noAnimals c3 aucs dprimes models outFile;
%     end
%     fprintf('%s all C3 evaluated\n',type2{j});
%     
%     % organic C3, inorganic C3, + k-means C2
%     outFile = [outDir type2{j} '-all-C3-plus-kmeans-evaluation.mat'];
%     if ~exist(outFile,'file')
%         aucs = nan(size(labels,1),length(nTrainingExamples),nRuns);
%         dprimes  = nan(size(labels,1),length(nTrainingExamples),nRuns);
%         models = cell(size(labels,1),length(nTrainingExamples),nRuns);
%         c2Animals = load([imgDir 'c2Cache/animals.kmeans.c2.mat'], 'c2');
%         c2NoAnimals = load([imgDir 'c2Cache/noAnimals.kmeans.c2.mat'], 'c2');
%         c3AnimalsOrganic = load([imgDir 'c2Cache/animals.organic.' type2{j} '.c3.mat'], 'c3');
%         c3AnimalsInorganic = load([imgDir 'c2Cache/animals.inorganic.' type2{j} '.c3.mat'], 'c3');
%         c3NoAnimalsOrganic = load([imgDir 'c2Cache/noAnimals.organic.' type2{j} '.c3.mat'], 'c3');
%         c3NoAnimalsInorganic = load([imgDir 'c2Cache/noAnimals.inorganic.' type2{j} '.c3.mat'], 'c3');
%         completeC2C3 = [c2Animals.c2          c2NoAnimals.c2 ; ... 
%                         c3AnimalsOrganic.c3   c3NoAnimalsOrganic.c3; ...
%                         c3AnimalsInorganic.c3 c3NoAnimalsInorganic.c3];
%         for iClass = 1:size(labels,1)
%             for iRun = 1:nRuns
%                 c2c3{iRun} = completeC2C3(~patchPerfSplit{iClass,1,iRun},:);
%                 [aucs(iClass,:,iRun),dprimes(iClass,:,iRun),models(iClass,:,iRun)] = ...
%                   evaluatePerformance(c2c3{iRun},...
%                   labels(~patchPerfSplit{iClass,1,iRun}),...
%                   cvsplit(iClass,:,iRun),method,options,size(c2c3{iRun},1),[]);
%             end
%         end
%         save(outFile,'labels','c2c3','aucs','dprimes', 'models','-v7.3');
%         clear animals noAnimals c2c3 aucs dprimes models outFile;
%     end
%     fprintf('%s all C3 + kmeans evaluated\n',type2{j});
% end
