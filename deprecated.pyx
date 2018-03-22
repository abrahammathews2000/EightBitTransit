from __future__ import division
import numpy as np
cimport numpy as np
import copy
import matplotlib.pyplot as plt
#from libcpp cimport bool as cybool

from .cTransitingImage import *
from .cGridFunctions import *
from .misc import *
from .inversion import *


__all__ = ['ART','ART_normal','neighborPermutations', 
'AStarGeneticStep', 'LCfromSummedPixels', 
'AStarGeneticStep_pixsum', 'AStarGeneticStep_pixsum_complete', 'wedgeOptimize']

cpdef ART(tau_init, A, obsLC, obsLCerr, mirrored=False, RMSstop=1.e-6, reg=0., n_iter=0):
    """
    Use the algebraic reconstruction technique to solve the system A*tau = np.ones_like(obsLC) - obsLC.
    
    Inputs:
    tau_init = initial guess for the raveled opacity vector tau (shape = NM = k)
    A = matrix of pixel overlap areas (shape = (NM, NM) = (k, k))
    obsLC = observed normalized flux values in the light curve (shape = NM = k)
    mirrored = whether tau is strictly mirrored about the horizontal midplane or not
    RMSstop = stopping criterion
    
    Outputs:
    tau = opacity vector
    """
    cdef:
        int N, M, q, RMSidx, rowidx
        double RMSarr[10]
        double RMSdiff, testRMS, dotp, denom, testRMSp1, RMSmean
        list RMSmeans, tau_updates, taus

    tau = np.ravel(tau_init)
    N = np.shape(tau_init)[0]
    M = np.shape(tau_init)[1]
    RHS = np.ones_like(obsLC) - obsLC
    
    RMSarr = np.ones((10,))
    RMSmean = np.mean(RMSarr)
    RMSmeans = []
    taus = []
    taus.append(np.zeros_like(tau))
    taus.append(tau)
    tau_updates = []
    tau_updates.append(np.zeros_like(tau))
    q = 0
    RMSidx = 0
    
    testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(tau,(N*M,1)))
    testRMS = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
    RMSdiff = 1.

    A = A + (reg * np.eye(N=np.shape(A)[1]))
    
    if mirrored is False:
        #while RMSmean > RMSstop:
        for q in range(0, n_iter):
            if q % 100 == 0:
                testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(tau,(N*M,1)))
                testLC = testLC[:,0]
                testRMS = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
            
            rowidx = q % (np.shape(A)[0])
            #rowidx = np.random.randint(0,np.shape(A)[0])
        
            dotp = np.dot(A[rowidx], tau)
            denom = (np.linalg.norm(A[rowidx]))**2
        
            tau_update = ((RHS[rowidx] - dotp)/denom) * A[rowidx]
            
            tau = tau + tau_update
            

            if q % 100 == 0:
                tau_update_tracked = np.zeros_like(tau_update)
                tau_tracked = copy.copy(tau)
                for trackidx in range(0,len(tau)):
                    rowidx = trackidx % (np.shape(A)[0])
                    dotp = np.dot(A[rowidx], tau)
                    denom = (np.linalg.norm(A[rowidx]))**2
                    tau_update_tracked += ((RHS[rowidx] - dotp)/denom) * A[rowidx]
                tau_tracked += tau_update_tracked
                tau_updates.append(tau_update_tracked)
                taus.append(tau_tracked)
                testtau = np.round(wedgeRearrange(np.round(wedgeRearrange(np.round(wedgeRearrange(np.reshape(tau,(N,M))),2)),2)),2)
                testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(testtau,(N*M,1)))
                testLC = testLC[:,0]
                testRMSp1 = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
                RMSdiff = np.abs(testRMSp1 - testRMS)
                #RMSarr[RMSidx%10] = RMSdiff
                RMSarr[RMSidx%10] = testRMSp1
                RMSmean = np.mean(RMSarr)
                RMSidx = RMSidx + 1
                RMSmeans.append(RMSmean)
                
            
            q = q + 1
            
    else:
        #while RMSmean > RMSstop:
        for q in range(0, n_iter):
            if q % 100 == 0:
                testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(tau,(N*M,1)))
                testLC = testLC[:,0]
                testRMS = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
                
            rowidx = q % (np.shape(A)[0])
            #rowidx = np.random.randint(0,np.shape(A)[0])
        
            dotp = np.dot(A[rowidx], tau)
            denom = (np.linalg.norm(A[rowidx]))**2
        
            tau_update = ((RHS[rowidx] - dotp)/denom) * A[rowidx]
            
            tau_update = tau_update.reshape((N,M))
            
            for row in range(int(np.floor(N/2)),N):
                tau_update[row] = tau_update[N-1-row]
                
            tau_update = tau_update.reshape(len(tau))
            
            tau = tau + tau_update
            

            if q % 100 == 0:
                tau_update_tracked = np.zeros_like(tau_update)
                tau_tracked = copy.copy(tau)
                for trackidx in range(0,len(tau)):
                    rowidx = trackidx % (np.shape(A)[0])
                    dotp = np.dot(A[rowidx], tau)
                    denom = (np.linalg.norm(A[rowidx]))**2
                    tau_update_tracked += ((RHS[rowidx] - dotp)/denom) * A[rowidx]
                tau_tracked += tau_update_tracked
                tau_updates.append(tau_update_tracked)
                taus.append(tau_tracked)
                testtau = np.round(wedgeRearrange(np.round(wedgeRearrange(np.round(wedgeRearrange(np.reshape(tau,(N,M))),2)),2)),2)
                testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(testtau,(N*M,1)))
                testLC = testLC[:,0]
                testRMSp1 = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
                RMSdiff = np.abs(testRMSp1 - testRMS)
                #RMSarr[RMSidx%10] = RMSdiff
                RMSarr[RMSidx%10] = testRMSp1
                RMSmean = np.mean(RMSarr)
                RMSidx = RMSidx + 1
                RMSmeans.append(RMSmean)
                
            q = q + 1
    
    fig = plt.figure(figsize=(8,6))
    plt.plot(RMSmeans)
    plt.yscale('log')
    plt.xscale('log')
    plt.title("RMS",fontsize=14)
    plt.show()

    taus_arr = np.array(taus)
    #print taus_arr[0]
    tau_updates_arr = np.array(tau_updates)
    #print np.shape(tau_updates_arr)

    
    fig = plt.figure(figsize=(8,6))
    for tau_entry in range(0,np.shape(tau_updates_arr)[1]):
    #for tau_entry in range(0,5):
        #print np.max(np.abs(tau_updates_arr[:,tau_entry]))
        #print np.min(np.abs(tau_updates_arr[:,tau_entry]))
        plt.plot(np.abs(tau_updates_arr[:,tau_entry]),alpha=0.7)
    plt.xscale('log')
    plt.yscale('log')
    plt.xlim(0,np.shape(tau_updates_arr)[0])
    plt.ylim(1.e-10,1.e0)
    plt.title("Tau updates", fontsize=14)
    plt.show()

    fig = plt.figure(figsize=(8,6))
    for tau_entry in range(0,np.shape(taus_arr)[1]):
    #for tau_entry in range(0,5):
        plt.plot(taus_arr[:,tau_entry],alpha=0.7)
    plt.xscale('log')
    plt.xlim(0,np.shape(tau_updates_arr)[0])
    plt.ylim(-0.1,1.1)
    plt.title("Taus", fontsize=14)
    plt.show()
    #print q
    #print RMSarr
    return tau


cpdef ART_normal(tau_init, A, obsLC, obsLCerr, reg=0., mirrored=False, RMSstop=1.e-6):
    """
    Use the algebraic reconstruction technique to solve the system A.T * A * tau = A.T * (np.ones_like(obsLC) - obsLC).
    
    Inputs:
    tau_init = initial guess for the raveled opacity vector tau (shape = NM = k)
    A = matrix of pixel overlap areas (shape = (NM, NM) = (k, k))
    obsLC = observed normalized flux values in the light curve (shape = NM = k)
    reg = regularization parameter (scalar)
    mirrored = whether tau is strictly mirrored about the horizontal midplane or not
    RMSstop = stopping criterion
    
    
    Outputs:
    tau = opacity vector
    """
    cdef:
        int N, M, q, RMSidx, rowidx
        double RMSarr[10]
        double RMSdiff, testRMS, dotp, denom, testRMSp1, RMSmean
        list RMSmeans

    tau = np.ravel(tau_init)
    N = np.shape(tau_init)[0]
    M = np.shape(tau_init)[1]
    
    if ((np.shape(A)[0] == np.shape(A)[1]) & (reg==0.)):
        RHS = np.ones_like(obsLC) - obsLC
        
    else:
        RHS = np.dot(A.T, np.ones_like(obsLC) - obsLC)
        A = np.dot(A.T, A) + (reg * np.eye(N=np.shape(A)[1]))
    
    RMSarr = np.ones((10,))
    RMSmean = np.mean(RMSarr)
    RMSmeans = []
    q = 0
    RMSidx = 0
    
    testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(tau,(N*M,1)))
    testRMS = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
    RMSdiff = 1.
    if mirrored is False:
        while RMSmean > RMSstop:
        #for q in range(0, n_iter):
            if q % 10000 == 0:
                testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(tau,(N*M,1)))
                testLC = testLC[:,0]
                testRMS = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
            
            rowidx = q % (np.shape(A)[0])
            #rowidx = np.random.randint(0,np.shape(A)[0])
        
            dotp = np.dot(A[rowidx], tau)
            denom = (np.linalg.norm(A[rowidx]))**2
        
            tau_update = ((RHS[rowidx] - dotp)/denom) * A[rowidx]
        
            tau = tau + tau_update
            
            if q % 10000 == 0:
                #print q
                testtau = np.round(wedgeRearrange(np.round(wedgeRearrange(np.round(wedgeRearrange(np.reshape(tau,(N,M))),2)),2)),2)
                
                testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(testtau,(N*M,1)))
                testLC = testLC[:,0]
                testRMSp1 = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
                RMSdiff = np.abs(testRMSp1 - testRMS)
                #RMSarr[RMSidx%10] = RMSdiff
                RMSarr[RMSidx%10] = testRMSp1
                RMSmean = np.mean(RMSarr)
                RMSidx = RMSidx + 1
                RMSmeans.append(RMSmean)
                
            
            q = q + 1

    else:
        while RMSmean > RMSstop:
        #for q in range(0, n_iter):
            if q % 10000 == 0:
                testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(tau,(N*M,1)))
                testLC = testLC[:,0]
                testRMS = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
                
            rowidx = q % (np.shape(A)[0])
            #rowidx = np.random.randint(0,np.shape(A)[0])
        
            dotp = np.dot(A[rowidx], tau)
            denom = (np.linalg.norm(A[rowidx]))**2
        
            tau_update = ((RHS[rowidx] - dotp)/denom) * A[rowidx]
            
            tau_update = tau_update.reshape((N,M))
            
            for row in range(int(np.floor(N/2)),N):
                tau_update[row] = tau_update[N-1-row]
                
            tau_update = tau_update.reshape(len(tau))
            
            tau = tau + tau_update

            if q % 10000 == 0:
                #print q
                testtau = np.round(wedgeRearrange(np.round(wedgeRearrange(np.round(wedgeRearrange(np.reshape(tau,(N,M))),2)),2)),2)
                
                testLC = np.atleast_2d(np.ones_like(RHS)).T - np.dot(A,np.reshape(testtau,(N*M,1)))
                testLC = testLC[:,0]
                testRMSp1 = RMS(LC_obs=obsLC,LC_obs_err=obsLCerr,LC_model=testLC)
                RMSdiff = np.abs(testRMSp1 - testRMS)
                #RMSarr[RMSidx%10] = RMSdiff
                RMSarr[RMSidx%10] = testRMSp1
                RMSmean = np.mean(RMSarr)
                RMSidx = RMSidx + 1
                RMSmeans.append(RMSmean)
                
            q = q + 1
    
    fig = plt.figure(figsize=(8,6))
    plt.plot(RMSmeans)
    plt.yscale('log')
    plt.show()
    #print q
    return tau

def neighborPermutations(grid,grid_i,grid_j,wraparound=False):
    """
    Inputs:
    grid = a grid of 1s and 0s
    grid_i = the row index of a particular pixel
    grid_j = the column index of the same pixel
    
    Returns:
    neighbors = Set of (at maximum) 1024 (=2**(3*3 + 1)) base-10 numbers describing every permutation of this pixel 
    and its 8 immediate neighbors, plus its counterpart across the horizontal midplane, on and off. For small grids, 
    the neighbor across the midplane may be an immediate neighbor; it won't be counted twice, and the output array will 
    be of length 512.
    
    At the edges of the grid, this algorithm will "wrap," so pixels from the opposite edge will be counted as neighbors.
    """
    
    neighbors = set()
    
    N = np.shape(grid)[0]
    M = np.shape(grid)[1]
    #print N,M
    assert grid_i < N, "i out of bounds"
    assert grid_j < M, "j out of bounds"
    
    #find counterpart across the horizontal midplane
    mirror_i = int(((N/2. - (grid_i+0.5)) + N/2.) - 0.5)
    mirror_j = grid_j
    
    #find neighbors
    #vertical
    if grid_i == 0:
        if wraparound is True:
            neighbors_i = [N-1, 0, 1]
        else:
            neighbors_i = [0, 1]
    elif grid_i == N-1:
        if wraparound is True:
            neighbors_i = [N-2, N-1, 0]
        else:
            neighbors_i = [N-2, N-1]
    else:
        neighbors_i = [grid_i - 1, grid_i, grid_i + 1]
    
    #horizontal
    if grid_j == 0:
        if wraparound is True:
            neighbors_j = [M-1, 0, 1]
        else:
            neighbors_j = [0, 1]
    elif grid_j == M-1:
        if wraparound is True:
            neighbors_j = [M-2, M-1, 0]
        else:
            neighbors_j = [M-2, M-1]
    else:
        neighbors_j = [grid_j - 1, grid_j, grid_j + 1]
    
    #print neighbors_i
    #print neighbors_j
    #get indices of these 9 neighbor grid positions into the raveled pixel grid (1D array of length NM)
    ravelidxs = []
    for k in range(0,len(neighbors_i)):
        for m in range(0,len(neighbors_j)):
            thisneighbor_i = neighbors_i[k]
            thisneighbor_j = neighbors_j[m]
            
            ravelidxs.append(thisneighbor_j + M*thisneighbor_i)
    #add in index of the counterpart across the midplane
    #ravelidxs.append(mirror_j + M*mirror_i)
    
    #sort these and make sure you're not double-counting the midplane counterpart
    ravelidxs = np.sort(np.unique(np.array(ravelidxs)))
    
    #print ravelidxs
    #Take the raveled pixel grid and substitute in all possible 2**10 (or 2**9) pixel arrangements at the positions
    #specified by ravelidxs.
    
    for i in range(2**(len(ravelidxs))):
        ravelgrid = np.ravel(grid)
        #print ravelgrid
        permute_arr = str(bin(i))[2:].zfill(len(ravelidxs))
        #print permute_arr
        permute_arr = np.array([int(n) for n in permute_arr])
        #print permute_arr
        
        for j in range(0,len(ravelidxs)):
            ravelgrid[ravelidxs[j]] = permute_arr[j]
        
        #print ravelgrid
        #convert to base-10 number
        ravelgrid = ravelgrid[::-1]
        #print ravelgrid
        
        base10number = ''.join(str(int(k)) for k in ravelgrid).lstrip('0')
        
        #print base10number
        #catch case where all are 0, and hence all are stripped
        try:
            base10number = int(base10number,2)
        except ValueError:
            base10number = 0
        
        #print base10number
        #add to "neighbors" set
        neighbors.add(base10number)
        
    return neighbors

def AStarGeneticStep(currentgrid, obsLC, obsLCerr, times, saveplots=False, filename="astrofestpetridish"):
    """
    Find the grid that best matches obsLC.
    """
    
    N = np.shape(currentgrid)[0]
    M = np.shape(currentgrid)[1]
    #print N, M
    
    currentti = TransitingImage(opacitymat=currentgrid, LDlaw="uniform", v=0.4, t_ref=0., t_arr=times)
    currentLC = currentti.gen_LC(times)   
    currentcost = RMS(obsLC, obsLCerr, currentLC)
    
    numfig=0
    nside=N
    
    if saveplots==True:
        fig, ax = plt.subplots(1,1,figsize=(6,6))
        ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
        ax.set_xlim(-0.5,nside-0.5)
        ax.set_ylim(nside-0.5,-0.5)
        ax.set_xticks(np.arange(-0.5,nside+0.5,1));
        ax.set_yticks(np.arange(-0.5,nside+0.5,1));
        ax.axes.get_xaxis().set_ticklabels([])
        ax.axes.get_yaxis().set_ticklabels([])
        #print "saved {0}".format(numfig)
        plt.grid(which='major', color='k', linestyle='-', linewidth=1)
        plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
    
        numfig+=1
    
    #print currentcost
    
    alreadyEvaluated = set()
    alreadyEvaluated.add(fromBinaryGrid(currentgrid))
    
    #print alreadyEvaluated
    
    #choose random "on" pixel
    onmask = np.ravel((currentgrid > 0.))
    
    onidxs = np.arange(0,len(np.ravel(currentgrid)))[onmask]
    
    randompix = np.random.choice(onidxs,1)[0]
    pixAlready = [randompix]
    
    randompix_i = randompix // N
    randompix_j = randompix % M
    
    #print randompix_i, randompix_j
    
    
    #why isn't the below working for grids bigger than 4x4??
    notYetEvaluated = neighborPermutations(grid=copy.copy(currentgrid),grid_i=randompix_i,grid_j=randompix_j)
    #print notYetEvaluated
    
    while len(notYetEvaluated) > 0:
        for checkBase10 in notYetEvaluated:
            checkGrid = toBinaryGrid(checkBase10,N,M)
            ti = TransitingImage(opacitymat=checkGrid, LDlaw="uniform", v=0.4, t_ref=0., t_arr=times)
            LC = ti.gen_LC(times)   
            cost = RMS(obsLC, obsLCerr, LC)
            
            alreadyEvaluated.add(checkBase10)
            
            if cost == 0:
                currentgrid = checkGrid
                currentcost = cost
                
                if saveplots==True:
                    fig, ax = plt.subplots(1,1,figsize=(6,6))
                    ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
                    ax.set_xlim(-0.5,nside-0.5)
                    ax.set_ylim(nside-0.5,-0.5)
                    ax.set_xticks(np.arange(-0.5,nside+0.5,1));
                    ax.set_yticks(np.arange(-0.5,nside+0.5,1));
                    ax.axes.get_xaxis().set_ticklabels([])
                    ax.axes.get_yaxis().set_ticklabels([])
                    plt.grid(which='major', color='k', linestyle='-', linewidth=1)
                    plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
                    #print "saved {0}".format(numfig)
    
                    numfig+=1
                #print len(alreadyEvaluated)
                return currentgrid, currentcost
            
            elif cost <= currentcost:
                currentgrid = checkGrid
                currentcost = cost
                
                if saveplots==True:
                    fig, ax = plt.subplots(1,1,figsize=(6,6))
                    ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
                    ax.set_xlim(-0.5,nside-0.5)
                    ax.set_ylim(nside-0.5,-0.5)
                    ax.set_xticks(np.arange(-0.5,nside+0.5,1));
                    ax.set_yticks(np.arange(-0.5,nside+0.5,1));
                    ax.axes.get_xaxis().set_ticklabels([])
                    ax.axes.get_yaxis().set_ticklabels([])
                    plt.grid(which='major', color='k', linestyle='-', linewidth=1)
                    plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
                    #print "saved {0}".format(numfig)
    
                    numfig+=1
            
            else:
                pass
        
        #print currentgrid
        #print currentcost
        notYetEvaluated.difference_update(alreadyEvaluated)
        
        #select a new "on" pixel to test
        onmask = np.ravel((currentgrid > 0.))
    
        onidxs = np.arange(0,len(np.ravel(currentgrid)))[onmask]
        
        #if we've already tried all of the choices
        if np.all(np.in1d(onidxs,np.array(pixAlready))):
            #print pixAlready
            #print "try off pixel"
            onidxs = np.arange(0,len(np.ravel(currentgrid)))[~onmask]
        
        randompix = np.random.choice(onidxs,1)[0]
        
        #make sure we haven't already tried this
        while randompix in pixAlready:
            randompix = np.random.choice(onidxs,1)[0]
            #if we've tried every pixel
            if len(pixAlready)==len(np.ravel(currentgrid)):
                #print len(alreadyEvaluated)
                return currentgrid, currentcost
        
        pixAlready.append(randompix)
    
        randompix_i = randompix // N
        randompix_j = randompix % M
        #print randompix_i, randompix_j
        #update with permutations about this new pixel
        newPermutations = neighborPermutations(grid=copy.copy(currentgrid),grid_i=randompix_i,grid_j=randompix_j)
        
        newPermutations.difference_update(alreadyEvaluated)
        notYetEvaluated.update(newPermutations)
    
    #print len(alreadyEvaluated)
    return currentgrid, currentcost

def LCfromSummedPixels(base10number, LCdecrements):
    """
    Takes base10number, figures out which pixels are "on", sums up those pixels' contributions from
    LCdecrements, outputs resulting light curve.
    """

    grid = toBinaryGrid(base10number,N=np.shape(LCdecrements)[0],M=np.shape(LCdecrements)[1])
    
    onpixdecrements = LCdecrements[grid.astype(bool)]
    
    onpixdecrements = np.sum(onpixdecrements,axis=0)
    
    LC = np.ones_like(onpixdecrements) - onpixdecrements
    return LC

def AStarGeneticStep_pixsum(currentgrid, obsLC, obsLCerr, times, saveplots=False, filename="astrofestpetridish",costfloor=1.e-10,perimeterFac=0.1):
    """
    Find the grid that best matches obsLC.
    
    Instead of recalculating the light curve from the grid every time, just sum up the light curves produced by individual
    transiting pixels.
    """
    
    N = np.shape(currentgrid)[0]
    M = np.shape(currentgrid)[1]
    
    tested_i = []
    tested_j = []
    costList = []
    currentcost = 1 - perimeterFac*compactness(currentgrid)
    #get array of flux decrements due to each individual pixel being "on"
    LCdecrements = np.zeros((N, M, len(times)))
    
    for i in range(N):
        for j in range(M):
            onepixgrid = np.zeros((N,M),dtype=int)
            onepixgrid[i,j] = 1
            onepix_ti = TransitingImage(opacitymat=onepixgrid, LDlaw="uniform", v=0.4, t_ref=0., t_arr=times)
            onepix_LC = onepix_ti.gen_LC(times)
            onepixcost = RMS(obsLC,obsLCerr,onepix_LC) + (1 - perimeterFac*compactness(onepixgrid)) #(100.*(1./(N*M)))
            if onepixcost <= costfloor:
                costList.append(onepixcost)
                return onepixgrid, onepixcost, costList, tested_i, tested_j
            
            LCdecrements[i,j,:] = np.ones_like(onepix_LC) - onepix_LC
    
    currentLC = LCfromSummedPixels(fromBinaryGrid(currentgrid),LCdecrements)  
    onmask = np.ravel((currentgrid > 0.))
    onidxs = np.arange(0,len(np.ravel(currentgrid)))[onmask]
    currentcost = RMS(obsLC,obsLCerr,currentLC) + (1 - perimeterFac*compactness(currentgrid)) #(100.*(len(onidxs)/(N*M)))
    costList.append(currentcost)
    
    numfig=0
    nside=N
    
    if saveplots==True:
        fig, ax = plt.subplots(1,1,figsize=(6,6))
        ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
        ax.set_xlim(-0.5,nside-0.5)
        ax.set_ylim(nside-0.5,-0.5)
        ax.set_xticks(np.arange(-0.5,nside+0.5,1));
        ax.set_yticks(np.arange(-0.5,nside+0.5,1));
        ax.axes.get_xaxis().set_ticklabels([])
        ax.axes.get_yaxis().set_ticklabels([])
        #print "saved {0}".format(numfig)
        plt.grid(which='major', color='k', linestyle='-', linewidth=1)
        plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
    
        numfig+=1
    
    #print currentcost
    
    alreadyEvaluated = set()
    alreadyEvaluated.add(fromBinaryGrid(currentgrid))
    
    #print alreadyEvaluated
    
    #choose random "on" pixel
    onmask = np.ravel((currentgrid > 0.))
    
    onidxs = np.arange(0,len(np.ravel(currentgrid)))[onmask]
    
    randompix = np.random.choice(onidxs,1)[0]
    pixAlready = [randompix]
    
    randompix_i = randompix // N
    randompix_j = randompix % M
    
    #print randompix_i, randompix_j
    tested_i.append(randompix_i)
    tested_j.append(randompix_j)
    
    notYetEvaluated = neighborPermutations(grid=copy.copy(currentgrid),grid_i=randompix_i,grid_j=randompix_j)
    #print notYetEvaluated
    
    while len(notYetEvaluated) > 0:
        for checkBase10 in notYetEvaluated:
            checkGrid = toBinaryGrid(checkBase10,N,M)
            
            LC = LCfromSummedPixels(checkBase10,LCdecrements)
            checkonmask = np.ravel((checkGrid > 0.))
            checkonidxs = np.arange(0,len(np.ravel(checkGrid)))[checkonmask]
            cost = RMS(obsLC, obsLCerr, LC) + (1 - perimeterFac*compactness(checkGrid)) #(100.*(len(checkonidxs)/(N*M)))
            
            alreadyEvaluated.add(checkBase10)
            
            if cost <= costfloor:
                currentgrid = checkGrid
                currentcost = cost
                costList.append(currentcost)
                
                if saveplots==True:
                    fig, ax = plt.subplots(1,1,figsize=(6,6))
                    ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
                    ax.set_xlim(-0.5,nside-0.5)
                    ax.set_ylim(nside-0.5,-0.5)
                    ax.set_xticks(np.arange(-0.5,nside+0.5,1));
                    ax.set_yticks(np.arange(-0.5,nside+0.5,1));
                    ax.axes.get_xaxis().set_ticklabels([])
                    ax.axes.get_yaxis().set_ticklabels([])
                    plt.grid(which='major', color='k', linestyle='-', linewidth=1)
                    plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
                    #print "saved {0}".format(numfig)
    
                    numfig+=1
                #print len(alreadyEvaluated)
                return currentgrid, currentcost, costList, tested_i, tested_j
            
            elif cost <= currentcost:
                currentgrid = checkGrid
                currentcost = cost
                costList.append(currentcost)
                
                if saveplots==True:
                    fig, ax = plt.subplots(1,1,figsize=(6,6))
                    ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
                    ax.set_xlim(-0.5,nside-0.5)
                    ax.set_ylim(nside-0.5,-0.5)
                    ax.set_xticks(np.arange(-0.5,nside+0.5,1));
                    ax.set_yticks(np.arange(-0.5,nside+0.5,1));
                    ax.axes.get_xaxis().set_ticklabels([])
                    ax.axes.get_yaxis().set_ticklabels([])
                    plt.grid(which='major', color='k', linestyle='-', linewidth=1)
                    plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
                    #print "saved {0}".format(numfig)
    
                    numfig+=1
            
            else:
                pass
        
        #print currentgrid
        #print currentcost
        notYetEvaluated.difference_update(alreadyEvaluated)
        
        #select a new "on" pixel to test
        onmask = np.ravel((currentgrid > 0.))
    
        onidxs = np.arange(0,len(np.ravel(currentgrid)))[onmask]
        
        #if we've already tried all of the choices
        if np.all(np.in1d(onidxs,np.array(pixAlready))):
            #print pixAlready
            #print "try off pixel"
            onidxs = np.arange(0,len(np.ravel(currentgrid)))[~onmask]
        
        randompix = np.random.choice(onidxs,1)[0]
        
        #make sure we haven't already tried this
        while randompix in pixAlready:
            randompix = np.random.choice(onidxs,1)[0]
            #if we've tried every pixel
            if len(pixAlready)==len(np.ravel(currentgrid)):
                #print len(alreadyEvaluated)
                return currentgrid, currentcost, costList, tested_i, tested_j
        
        pixAlready.append(randompix)
    
        randompix_i = randompix // N
        randompix_j = randompix % M
        #print randompix_i, randompix_j
        tested_i.append(randompix_i)
        tested_j.append(randompix_j)
        #update with permutations about this new pixel
        newPermutations = neighborPermutations(grid=copy.copy(currentgrid),grid_i=randompix_i,grid_j=randompix_j)
        
        newPermutations.difference_update(alreadyEvaluated)
        notYetEvaluated.update(newPermutations)
    
    #print len(alreadyEvaluated)
    return currentgrid, currentcost, costList, tested_i, tested_j


def AStarGeneticStep_pixsum_complete(currentgrid, obsLC, obsLCerr, times, temperature=0.01, saveplots=False, filename="astrofestpetridish",costfloor=1.e-10,perimeterFac=0.1):
    """
    Find the grid that best matches obsLC.
    
    Instead of recalculating the light curve from the grid every time, just sum up the light curves produced by individual
    transiting pixels.
    """
    
    N = np.shape(currentgrid)[0]
    M = np.shape(currentgrid)[1]
    
    tested_i = []
    tested_j = []
    costList = []
    currentcost = 1. - perimeterFac*compactness(currentgrid)
    #get array of flux decrements due to each individual pixel being "on"
    LCdecrements = np.zeros((N, M, len(times)))
    
    for i in range(N):
        for j in range(M):
            onepixgrid = np.zeros((N,M),dtype=int)
            onepixgrid[i,j] = 1
            onepix_ti = TransitingImage(opacitymat=onepixgrid, LDlaw="uniform", v=0.4, t_ref=0., t_arr=times)
            onepix_LC = onepix_ti.gen_LC(times)
            onepixcost = RMS(obsLC,obsLCerr,onepix_LC) + (1. - perimeterFac*compactness(onepixgrid)) #(100.*(1./(N*M)))
            if onepixcost <= costfloor:
                costList.append(onepixcost)
                return onepixgrid, onepixcost, costList, tested_i, tested_j
            
            LCdecrements[i,j,:] = np.ones_like(onepix_LC) - onepix_LC
    
    currentLC = LCfromSummedPixels(fromBinaryGrid(currentgrid),LCdecrements)  
    onmask = np.ravel((currentgrid > 0.))
    onidxs = np.arange(0,len(np.ravel(currentgrid)))[onmask]
    currentcost = RMS(obsLC, obsLCerr, currentLC) + (1. - perimeterFac*compactness(currentgrid)) #(100.*(len(onidxs)/(N*M)))
    costList.append(currentcost)
    
    numfig=0
    nside=N
    
    if saveplots==True:
        fig, ax = plt.subplots(1,1,figsize=(6,6))
        ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
        ax.set_xlim(-0.5,nside-0.5)
        ax.set_ylim(nside-0.5,-0.5)
        ax.set_xticks(np.arange(-0.5,nside+0.5,1));
        ax.set_yticks(np.arange(-0.5,nside+0.5,1));
        ax.axes.get_xaxis().set_ticklabels([])
        ax.axes.get_yaxis().set_ticklabels([])
        #print "saved {0}".format(numfig)
        plt.grid(which='major', color='k', linestyle='-', linewidth=1)
        plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
    
        numfig+=1
    
    #print currentcost
    
    alreadyEvaluated = set()
    alreadyEvaluated.add(fromBinaryGrid(currentgrid))
    
    #print alreadyEvaluated
    
    #choose random "on" pixel
    onmask = np.ravel((currentgrid > 0.))
    
    onidxs = np.arange(0,len(np.ravel(currentgrid)))[onmask]
    
    pixAlready = []
    notYetEvaluated = set()
    for onidx in onidxs:
        pixAlready.append(onidx)
        onidx_i = onidx // N
        onidx_j = onidx % M
        tested_i.append(onidx_i)
        tested_j.append(onidx_j)

        notYetEvaluated.update(neighborPermutations(grid=copy.copy(currentgrid),grid_i=onidx_i,grid_j=onidx_j))
    
    while len(notYetEvaluated) > 0:
        for checkBase10 in notYetEvaluated:
            checkGrid = toBinaryGrid(checkBase10,N,M)
            
            LC = LCfromSummedPixels(checkBase10,LCdecrements)
            checkonmask = np.ravel((checkGrid > 0.))
            checkonidxs = np.arange(0,len(np.ravel(checkGrid)))[checkonmask]
            cost = RMS(obsLC, obsLCerr, LC) + (1. - perimeterFac*compactness(checkGrid)) #(100.*(len(checkonidxs)/(N*M)))
            
            alreadyEvaluated.add(checkBase10)
            
            if cost <= costfloor:
                currentgrid = checkGrid
                currentcost = cost
                costList.append(currentcost)
                
                if saveplots==True:
                    fig, ax = plt.subplots(1,1,figsize=(6,6))
                    ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
                    ax.set_xlim(-0.5,nside-0.5)
                    ax.set_ylim(nside-0.5,-0.5)
                    ax.set_xticks(np.arange(-0.5,nside+0.5,1));
                    ax.set_yticks(np.arange(-0.5,nside+0.5,1));
                    ax.axes.get_xaxis().set_ticklabels([])
                    ax.axes.get_yaxis().set_ticklabels([])
                    plt.grid(which='major', color='k', linestyle='-', linewidth=1)
                    plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
                    #print "saved {0}".format(numfig)
    
                    numfig+=1
                #print len(alreadyEvaluated)
                return currentgrid, currentcost, costList, tested_i, tested_j
            
            elif cost <= currentcost:
                currentgrid = checkGrid
                currentcost = cost
                costList.append(currentcost)
                
                if saveplots==True:
                    fig, ax = plt.subplots(1,1,figsize=(6,6))
                    ax.imshow(currentgrid,cmap="Greys",aspect="equal",origin="upper",interpolation='nearest',vmin=0,vmax=1)
                    ax.set_xlim(-0.5,nside-0.5)
                    ax.set_ylim(nside-0.5,-0.5)
                    ax.set_xticks(np.arange(-0.5,nside+0.5,1));
                    ax.set_yticks(np.arange(-0.5,nside+0.5,1));
                    ax.axes.get_xaxis().set_ticklabels([])
                    ax.axes.get_yaxis().set_ticklabels([])
                    plt.grid(which='major', color='k', linestyle='-', linewidth=1)
                    plt.savefig("./{0}{1}.pdf".format(filename,numfig), fmt="pdf")
                    #print "saved {0}".format(numfig)
    
                    numfig+=1
            
            else:
                pass
        
        #print currentgrid
        #print currentcost
        notYetEvaluated.difference_update(alreadyEvaluated)
        
        #select a new "on" pixel to test
        onmask = np.ravel((currentgrid > 0.))
    
        onidxs = np.arange(0,len(np.ravel(currentgrid)))[onmask]
        
        #if we've already tried all of the choices
        if np.all(np.in1d(onidxs,np.array(pixAlready))):
            #print pixAlready
            #print "try off pixel"
            onidxs = np.arange(0,len(np.ravel(currentgrid)))[~onmask]
        
        randompix = np.random.choice(onidxs,1)[0]
        
        #make sure we haven't already tried this
        while randompix in pixAlready:
            randompix = np.random.choice(onidxs,1)[0]
            #if we've tried every pixel
            if len(pixAlready)==len(np.ravel(currentgrid)):
                #print len(alreadyEvaluated)
                return currentgrid, currentcost, costList, tested_i, tested_j
        
        pixAlready.append(randompix)
    
        randompix_i = randompix // N
        randompix_j = randompix % M
        #print randompix_i, randompix_j
        tested_i.append(randompix_i)
        tested_j.append(randompix_j)
        #update with permutations about this new pixel
        newPermutations = neighborPermutations(grid=copy.copy(currentgrid),grid_i=randompix_i,grid_j=randompix_j)
        
        newPermutations.difference_update(alreadyEvaluated)
        notYetEvaluated.update(newPermutations)
    
    #print len(alreadyEvaluated)

    return currentgrid, currentcost, costList, tested_i, tested_j


def wedgeOptimize(tau, obsLC, obsLCerr, areas):
    """
    Exploit the "wedge degeneracy" to shift opacity around. This is different from wedgeRearrange because here, we're
    starting from a grid of physical opacities (0 <= tau <= 1).
    
    Strategy: Start from the middle, and pull opacity from the outermost row until the middle-most pixels are full or the outermost
    pixels are empty. Then move outward to the next-middlemost row, pulling opacity from the outermost row and then the next-outermost row, etc.

    """
    
    # Start at the middle of the grid
    N = np.shape(tau)[0]
    M = np.shape(tau)[1]
    middleN = int(np.floor((N-1)/2.))
    #print "middleN is {0}".format(middleN)
    
    w = 2./N
    
    newtau = copy.copy(tau)
    newtauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(newtau,(N*M,1)))
    newtauLC = newtauLC[:,0]
    newtauCost = RMS(obsLC, obsLCerr, newtauLC)
    proptau = copy.copy(newtau)
    
    #N even
    if N%2 == 0:
        #print "even"
        northRows = np.arange(middleN, -1, -1)
        southRows = np.arange(N-1-middleN, N, 1)
        b = w/2.
        outermost_b = 1. - w/2.
        
    #N odd
    else:
        #print "odd"
        northRows = np.arange(middleN-1, -1, -1)
        southRows = np.arange(N-middleN, N, 1)
        
        #pull opacity from outer rows to central row
        b = 0.
        #propPrior = (1.-b**2)**0.25 * w**2 # (1-b^2)^(1/4) * p^2, from Kipping & Sandford 2016
        
        #row that opacity is pulled from: loop from outermost to innermost rows
        for fillop in [1.0, 0.5]:
            for outerRow in range(0, middleN):
                #re-evaluate which pixels are full
                middleRow = proptau[middleN]
                #print middleRow
                middleRow_notfull = np.arange(0,M)[(middleRow > (fillop-0.5)) & (middleRow < fillop)]

                #print outerRow
                #print N-1-outerRow

                outer_b = 1. - w/2. - outerRow*w
                #print outer_b

                #get diameter of the star at that position in the limb
                outer_x = (2.*np.sqrt(1.-outer_b**2))/w
                #print "central row outer_x is {0}".format(outer_x)

                #width of pixel block with same transit duration [units of PIXELS]
                sameDuration = (w + 2.*np.sqrt(1.-b**2) - 2.*np.sqrt(1.-outer_b**2)) / w

                sameDuration_forOpacity = copy.copy(sameDuration)
                #prevent "same duration" block from becoming wider than the grid
                while sameDuration > M:
                    sameDuration = sameDuration - 2.

                while sameDuration > outer_x:
                    sameDuration = sameDuration - 2.

                sameDuration_int = 0
                sameDuration_leftover = copy.copy(sameDuration)
                while sameDuration_leftover > 1.:
                    sameDuration_int += 1
                    sameDuration_leftover -= 1

                if sameDuration_int%2 == 0:
                    sameDuration_int = sameDuration_int - 1
                    sameDuration_leftover = sameDuration_leftover + 1.

                sameDuration_forOpacity_int = 0
                sameDuration_forOpacity_leftover = copy.deepcopy(sameDuration_forOpacity)

                while sameDuration_forOpacity_leftover > 1.:
                    sameDuration_forOpacity_int += 1
                    sameDuration_forOpacity_leftover -= 1

                if sameDuration_forOpacity_int%2 == 0:
                    sameDuration_forOpacity_int = sameDuration_forOpacity_int - 1
                    sameDuration_forOpacity_leftover = sameDuration_forOpacity_leftover + 1.

                for j in middleRow_notfull:
                    #get spill-in column idxs (relative to idx of the pixel they're spilling into)
                    spillin_j = np.arange(j-(int(np.floor(sameDuration_int/2))), j+(int(np.floor(sameDuration_int/2))) + 1)
                    #print j
                    #print spillin_j
                    #eliminate columns outside the bounds of the grid
                    spillin_j = spillin_j[(spillin_j >= 0.) &  (spillin_j < M)]
                    #print spillin_j
                    extra_spillin_j = np.arange(j-(int(np.floor(sameDuration_forOpacity_int/2))), j+(int(np.floor(sameDuration_forOpacity_int/2))) + 1)
                    extra_spillin_j = extra_spillin_j[(extra_spillin_j >= 0.) &  (extra_spillin_j < M)]
                    extra_spillin_j = extra_spillin_j[np.where(np.in1d(extra_spillin_j, spillin_j, invert=True))[0]]

                    #let outermost opacities flow in, where the distribution of where the opacities come from is proportional to
                    # the pixel's "contribution" to the transit duration
                    amtToFill = fillop - middleRow[j]

                    #print "amtToFill is {0}".format(amtToFill)

                    directOverflowWeight = (fillop/sameDuration_forOpacity)
                    edgeOverflowWeight = (sameDuration_leftover/(2./fillop))

                    for col in spillin_j: #This only works if the input grid is symmetrical!!!!
                        if ((proptau[outerRow,col] - (directOverflowWeight*amtToFill)/2.) >= 0.) & (proptau[N-1-outerRow,col] - (directOverflowWeight*amtToFill)/2. >= 0.) & (proptau[middleN, j] + directOverflowWeight*amtToFill <= fillop):
                            proptau[middleN, j] += directOverflowWeight*amtToFill
                            proptau[outerRow,col] -= (directOverflowWeight*amtToFill)/2. #divide by 2 because middle row overflows both north and south
                            proptau[N-1-outerRow,col] -= (directOverflowWeight*amtToFill)/2. #divide by 2 because middle row overflows both north and south
                        elif ((proptau[outerRow,col] - (directOverflowWeight*amtToFill)/2.) < 0.) | (proptau[N-1-outerRow,col] - (directOverflowWeight*amtToFill)/2. < 0.):
                            proptau[middleN, j] += proptau[outerRow,col]
                            proptau[middleN, j] += proptau[N-1-outerRow,col]
                            proptau[outerRow, col] = 0.
                            proptau[N-1-outerRow, col] = 0.
                        elif (proptau[middleN, j] + directOverflowWeight*amtToFill > fillop):
                            excess = (fillop - proptau[middleN, j])/2.
                            proptau[middleN, j] = fillop
                            proptau[outerRow, col] -= excess
                            proptau[N-1-outerRow, col] -= excess 


                        leftCol = j - int(np.floor(sameDuration_int/2)) - 1
                        rightCol = j + int(np.floor(sameDuration_int/2)) + 1

                        while leftCol < 0:
                            leftCol = leftCol + 1
                        while rightCol > M-1:
                            rightCol = rightCol - 1

                        #left col
                        if ((proptau[outerRow,leftCol] - (edgeOverflowWeight*amtToFill)/2.) >= 0.) & (proptau[N-1-outerRow,leftCol] - (edgeOverflowWeight*amtToFill)/2. >= 0.) & (proptau[middleN, j] + edgeOverflowWeight*amtToFill <= fillop):
                            proptau[middleN, j] += edgeOverflowWeight*amtToFill
                            proptau[outerRow,leftCol] -= (edgeOverflowWeight*amtToFill)/2. #divide by 2 because middle row overflows both north and south
                            proptau[N-1-outerRow,leftCol] -= (edgeOverflowWeight*amtToFill)/2. #divide by 2 because middle row overflows both north and south
                        elif ((proptau[outerRow,leftCol] - (edgeOverflowWeight*amtToFill)/2.) < 0.) | (proptau[N-1-outerRow,leftCol] - (edgeOverflowWeight*amtToFill)/2. < 0.):
                            proptau[middleN, j] += proptau[outerRow,leftCol]
                            proptau[middleN, j] += proptau[N-1-outerRow,leftCol]
                            proptau[outerRow,leftCol] = 0.
                            proptau[N-1-outerRow,leftCol] = 0.
                        elif ((proptau[outerRow,leftCol] - (edgeOverflowWeight*amtToFill)/2.) >= 0.) & (proptau[N-1-outerRow,leftCol] - (edgeOverflowWeight*amtToFill)/2. >= 0.) & (proptau[middleN, j] + edgeOverflowWeight*amtToFill > fillop):
                            excess = (fillop - proptau[middleN, j])/2.
                            proptau[middleN, j] = fillop
                            proptau[outerRow,leftCol] -= excess 
                            proptau[N-1-outerRow,leftCol] -= excess

                        #right col
                        if ((proptau[outerRow,rightCol] - (edgeOverflowWeight*amtToFill)/2.) >= 0.) & (proptau[N-1-outerRow,rightCol] - (edgeOverflowWeight*amtToFill)/2. >= 0.) & (proptau[middleN, j] + edgeOverflowWeight*amtToFill <= fillop):
                            proptau[middleN, j] += edgeOverflowWeight*amtToFill
                            proptau[outerRow,rightCol] -= (edgeOverflowWeight*amtToFill)/2. #divide by 2 because middle row overflows both north and south
                            proptau[N-1-outerRow,rightCol] -= (edgeOverflowWeight*amtToFill)/2. #divide by 2 because middle row overflows both north and south       
                        elif ((proptau[outerRow,rightCol] - (edgeOverflowWeight*amtToFill)/2.) < 0.) | (proptau[N-1-outerRow,rightCol] - (edgeOverflowWeight*amtToFill)/2. < 0.):
                            proptau[middleN, j] += proptau[outerRow,rightCol]
                            proptau[middleN, j] += proptau[N-1-outerRow,rightCol]
                            proptau[outerRow,rightCol] = 0.
                            proptau[N-1-outerRow,rightCol] = 0.
                        elif ((proptau[outerRow,rightCol] - (edgeOverflowWeight*amtToFill)/2.) >= 0.) & (proptau[N-1-outerRow,rightCol] - (edgeOverflowWeight*amtToFill)/2. >= 0.) & (proptau[middleN, j] + edgeOverflowWeight*amtToFill > fillop):
                            excess = (fillop - proptau[middleN, j])/2.
                            proptau[middleN, j] = fillop
                            proptau[outerRow,rightCol] -= excess 
                            proptau[N-1-outerRow,rightCol] -= excess

                    for col in extra_spillin_j:
                        proptau[outerRow, col] = 0.

                    #account for prior in deciding whether to accept
                    propPrior = (1.-b**2)**0.25 * w**2 # (1-b^2)^(1/4) * p^2, from Kipping & Sandford 2016
                    oldPrior = 2*(1.-outer_b**2)**0.25 * (w**2 * sameDuration_forOpacity) #use area of spill-in pixel blocks to calculate ratio-of-radii proxy
            
                    proptauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(proptau,(N*M,1)))
                    proptauLC = proptauLC[:,0]
                    proptauCost = RMS(obsLC, obsLCerr, proptauLC)
                    
                    deltaRMS = np.exp(-0.5*(proptauCost**2 - newtauCost**2))
                    postRatio = deltaRMS * (propPrior/oldPrior)
                    
                    testProb = np.random.uniform(0.,1.)
                    if testProb < postRatio:
                        newtau = proptau
                        newtauCost = proptauCost
                        proptau = copy.copy(newtau)
                    else:
                        proptau = copy.copy(newtau)
            
        #do not account for prior in deciding whether to accept
        """proptauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(proptau,(N*M,1)))
        proptauLC = proptauLC[:,0]
        proptauCost = RMS(obsLC, obsLCerr, proptauLC)
        
        newtau = copy.copy(proptau)
        newtauCost = proptauCost
        proptau = copy.copy(newtau)"""
        
    #do the same for the next-middlemost rows, out toward the top and bottom of the grid.
    for fillop in [1.0, 0.5]:
        for row in northRows[:-1][::-1]: #no need to do it for the top row
            northRow = proptau[row]
            northRow_notfull = np.arange(0,M)[(northRow > (fillop-0.5)) & (northRow < fillop)]

            #pull opacity from outermost row first
            b = 1. - w/2. - row*w

            #print b

            #row that opacity is pulled from: loop from outermost to innermost rows
            for outerRow in range(0, row):
                #re-evaluate which pixels are full
                northRow = proptau[row]
                northRow_notfull = np.arange(0,M)[(northRow > (fillop-0.5)) & (northRow < fillop)]

                #get impact parameter of outer transiting row
                outer_b = 1. - w/2. - outerRow*w

                #get stellar diameter at that impact parameter
                outer_x = (2.*np.sqrt(1.-outer_b**2))/w

                #width of pixel block with same transit duration [units of PIXELS]
                sameDuration = (w + 2.*np.sqrt(1.-b**2) - 2.*np.sqrt(1.-outer_b**2)) / w

                sameDuration_forOpacity = copy.deepcopy(sameDuration)

                #prevent "same duration" block from becoming wider than the grid
                while sameDuration > M:
                    sameDuration = sameDuration - 2.

                while sameDuration > outer_x:
                    sameDuration = sameDuration - 2.

                sameDuration_int = 0
                sameDuration_leftover = copy.deepcopy(sameDuration)
                while sameDuration_leftover > 1.:
                    sameDuration_int += 1
                    sameDuration_leftover -= 1

                if sameDuration_int%2 == 0:
                    sameDuration_int = sameDuration_int - 1
                    sameDuration_leftover = sameDuration_leftover + 1.

                sameDuration_forOpacity_int = 0
                sameDuration_forOpacity_leftover = copy.deepcopy(sameDuration_forOpacity)

                while sameDuration_forOpacity_leftover > 1.:
                    sameDuration_forOpacity_int += 1
                    sameDuration_forOpacity_leftover -= 1

                if sameDuration_forOpacity_int%2 == 0:
                    sameDuration_forOpacity_int = sameDuration_forOpacity_int - 1
                    sameDuration_forOpacity_leftover = sameDuration_forOpacity_leftover + 1.

                for j in northRow_notfull:
                    #get spill-in column idxs (relative to idx of the pixel they're spilling into)
                    spillin_j = np.arange(j-(int(np.floor(sameDuration_int/2))), j+(int(np.floor(sameDuration_int/2))) + 1)
                    #eliminate columns outside the bounds of the grid
                    spillin_j = spillin_j[(spillin_j >= 0.) &  (spillin_j < M)]
                    #print "spillin_j is {0}".format(spillin_j)

                    extra_spillin_j = np.arange(j-(int(np.floor(sameDuration_forOpacity_int/2))), j+(int(np.floor(sameDuration_forOpacity_int/2))) + 1)
                    extra_spillin_j = extra_spillin_j[(extra_spillin_j >= 0.) &  (extra_spillin_j < M)]
                    extra_spillin_j = extra_spillin_j[np.where(np.in1d(extra_spillin_j, spillin_j, invert=True))[0]]
                    #print "extra_spillin_j is {0}".format(extra_spillin_j)

                    #let outermost opacities flow in, where the distribution of where the opacities come from is proportional to
                    # the pixel's "contribution" to the transit duration
                    amtToFill = fillop - northRow[j]

                    directOverflowWeight = (fillop/sameDuration_forOpacity)
                    edgeOverflowWeight = (sameDuration_forOpacity_leftover/(2./fillop))

                    for col in spillin_j: 
                        if ((proptau[outerRow,col] - (directOverflowWeight*amtToFill)) >= 0.) & (proptau[row,j] + directOverflowWeight*amtToFill <= fillop):
                            proptau[row, j] += directOverflowWeight*amtToFill
                            proptau[outerRow,col] -= (directOverflowWeight*amtToFill)
                        elif (proptau[outerRow,col] - (directOverflowWeight*amtToFill) < 0.):
                            proptau[row, j] += proptau[outerRow,col]
                            proptau[outerRow, col] = 0.
                        elif (proptau[row,j] + directOverflowWeight*amtToFill > fillop):
                            excess = fillop - proptau[row, j]
                            proptau[row, j] = fillop
                            proptau[outerRow, col] -= excess

                        leftCol = j - int(np.floor(sameDuration_int/2)) - 1
                        rightCol = j + int(np.floor(sameDuration_int/2)) + 1

                        while leftCol < 0:
                            leftCol = leftCol + 1
                        while rightCol > M-1:
                            rightCol = rightCol - 1

                        if ((proptau[outerRow,leftCol] - (edgeOverflowWeight*amtToFill)) >= 0.) & (proptau[row, j] + edgeOverflowWeight*amtToFill <= fillop) :
                            proptau[row, j] += edgeOverflowWeight*amtToFill
                            proptau[outerRow,leftCol] -= (edgeOverflowWeight*amtToFill)    
                        elif (proptau[outerRow,leftCol] - (edgeOverflowWeight*amtToFill) < 0.):
                            proptau[row, j] += proptau[outerRow,leftCol]
                            proptau[outerRow,leftCol] = 0.
                        elif (proptau[row, j] + edgeOverflowWeight*amtToFill > fillop):
                            excess = fillop - proptau[row,j]
                            proptau[row, j] = fillop
                            proptau[outerRow,leftCol] -= excess

                        if ((proptau[outerRow,rightCol] - (edgeOverflowWeight*amtToFill)) >= 0.) & (proptau[row, j] + edgeOverflowWeight*amtToFill <= fillop) :
                            proptau[row, j] += edgeOverflowWeight*amtToFill
                            proptau[outerRow,rightCol] -= (edgeOverflowWeight*amtToFill)    
                        elif (proptau[outerRow,rightCol] - (edgeOverflowWeight*amtToFill) < 0.):
                            proptau[row, j] += proptau[outerRow,rightCol]
                            proptau[outerRow,rightCol] = 0.
                        elif (proptau[row, j] + edgeOverflowWeight*amtToFill > fillop):
                            excess = fillop - proptau[row,j]
                            proptau[row, j] = fillop
                            proptau[outerRow,rightCol] -= excess

                    for col in extra_spillin_j:
                        proptau[outerRow, col] = 0.
                    
                    #account for prior in deciding whether to accept
                    propPrior = (1.-b**2)**0.25 * w**2 # (1-b^2)^(1/4) * p^2, from Kipping & Sandford 2016
                    oldPrior = (1.-outer_b**2)**0.25 * (w**2 * sameDuration_forOpacity) #use area of spill-in pixel blocks to calculate ratio-of-radii proxy
            
                    proptauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(proptau,(N*M,1)))
                    proptauLC = proptauLC[:,0]
                    proptauCost = RMS(obsLC, obsLCerr, proptauLC)
                    
                    deltaRMS = np.exp(-0.5*(proptauCost**2 - newtauCost**2))
                    postRatio = deltaRMS * (propPrior/oldPrior)
                    
                    testProb = np.random.uniform(0.,1.)
                    if testProb < postRatio:
                        #print "north better"
                        newtau = proptau
                        newtauCost = proptauCost
                        proptau = copy.copy(newtau)
                    else:
                        proptau = copy.copy(newtau)
            
        #do not account for prior in deciding whether to accept
        """proptauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(proptau,(N*M,1)))
        proptauLC = proptauLC[:,0]
        proptauCost = RMS(obsLC, obsLCerr, proptauLC)
        
        newtau = copy.copy(proptau)
        newtauCost = proptauCost
        proptau = copy.copy(newtau)"""
        
    
    for fillop in [1.0, 0.5]:
        for row in southRows[:-1][::-1]: #no need to do it for the top row
            #print "southRow is {0}".format(row)
            southRow = proptau[row]
            southRow_notfull = np.arange(0,M)[(southRow > (fillop-0.5)) & (southRow < fillop)]
            #print northRow_notfull

            #pull opacity from outermost row first
            b = 1. - w/2. - row*w

            #print b

            #row that opacity is pulled from: loop from outermost to innermost rows
            for outerRow in range(N-1, row, -1):
                #print outerRow
                #re-evaluate which pixels are full
                southRow = proptau[row]
                southRow_notfull = np.arange(0,M)[(southRow > (fillop-0.5)) & (southRow < fillop)]

                outer_b = 1. - w/2. - (N-1-outerRow)*w

                outer_x = (2.*np.sqrt(1.-outer_b**2))/w
                #print "south row outer_x is {0}".format(outer_x)

                #width of pixel block with same transit duration [units of PIXELS]
                sameDuration = (w + 2.*np.sqrt(1.-b**2) - 2.*np.sqrt(1.-outer_b**2)) / w

                sameDuration_forOpacity = copy.copy(sameDuration)
                #prevent "same duration" block from becoming wider than the grid
                while sameDuration > M:
                    sameDuration = sameDuration - 2.

                while sameDuration > outer_x:
                    #print "south row too wide"
                    sameDuration = sameDuration - 2.

                sameDuration_int = 0
                sameDuration_leftover = sameDuration
                while sameDuration_leftover > 1.:
                    sameDuration_int += 1
                    sameDuration_leftover -= 1

                if sameDuration_int%2 == 0:
                    sameDuration_int = sameDuration_int - 1
                    sameDuration_leftover = sameDuration_leftover + 1.

                sameDuration_forOpacity_int = 0
                sameDuration_forOpacity_leftover = copy.deepcopy(sameDuration_forOpacity)

                while sameDuration_forOpacity_leftover > 1.:
                    sameDuration_forOpacity_int += 1
                    sameDuration_forOpacity_leftover -= 1

                if sameDuration_forOpacity_int%2 == 0:
                    sameDuration_forOpacity_int = sameDuration_forOpacity_int - 1
                    sameDuration_forOpacity_leftover = sameDuration_forOpacity_leftover + 1.

                for j in southRow_notfull:
                    #get spill-in column idxs (relative to idx of the pixel they're spilling into)
                    spillin_j = np.arange(j-(int(np.floor(sameDuration_int/2))), j+(int(np.floor(sameDuration_int/2))) + 1)
                    #print j
                    #print spillin_j
                    #eliminate columns outside the bounds of the grid
                    spillin_j = spillin_j[(spillin_j >= 0.) &  (spillin_j < M)]
                    #print spillin_j
                    
                    
                    #find pixels to pull opacity from and then set to 0 opacity
                    extra_spillin_j = np.arange(j-(int(np.floor(sameDuration_forOpacity_int/2))), j+(int(np.floor(sameDuration_forOpacity_int/2))) + 1)
                    extra_spillin_j = extra_spillin_j[(extra_spillin_j >= 0.) &  (extra_spillin_j < M)]
                    extra_spillin_j = extra_spillin_j[np.where(np.in1d(extra_spillin_j, spillin_j, invert=True))[0]]
                    #print extra_spillin_j
                    #let outermost opacities flow in, where the distribution of where the opacities come from is proportional to
                    # the pixel's "contribution" to the transit duration
                    amtToFill = fillop - southRow[j]

                    #print "amtToFill is {0}".format(amtToFill)

                    directOverflowWeight = (fillop/sameDuration_forOpacity)
                    edgeOverflowWeight = (sameDuration_leftover/(2./fillop))

                    for col in spillin_j: #This only works if the input grid is symmetrical!!!!   
                        if ((proptau[outerRow,col] - (directOverflowWeight*amtToFill)) >= 0.) & (proptau[row,j] + directOverflowWeight*amtToFill <= fillop):
                            proptau[row, j] += directOverflowWeight*amtToFill
                            proptau[outerRow,col] -= (directOverflowWeight*amtToFill)
                        elif (proptau[outerRow,col] - (directOverflowWeight*amtToFill) < 0.):
                            proptau[row, j] += proptau[outerRow,col]
                            proptau[outerRow, col] = 0.
                        elif (proptau[row,j] + directOverflowWeight*amtToFill > fillop):
                            excess = fillop - proptau[row, j]
                            proptau[row, j] = fillop
                            proptau[outerRow, col] -= excess

                        leftCol = j - int(np.floor(sameDuration_int/2)) - 1
                        rightCol = j + int(np.floor(sameDuration_int/2)) + 1
                        #print leftCol
                        #print rightCol
                        
                        while leftCol < 0:
                            leftCol = leftCol + 1
                        while rightCol > M-1:
                            rightCol = rightCol - 1
                        
                        
                        if ((proptau[outerRow,leftCol] - (edgeOverflowWeight*amtToFill)) >= 0.) & (proptau[row, j] + edgeOverflowWeight*amtToFill <= fillop) :
                            proptau[row, j] += edgeOverflowWeight*amtToFill
                            proptau[outerRow,leftCol] -= (edgeOverflowWeight*amtToFill)    
                        elif (proptau[outerRow,leftCol] - (edgeOverflowWeight*amtToFill) < 0.):
                            proptau[row, j] += proptau[outerRow,leftCol]
                            proptau[outerRow,leftCol] = 0.
                        elif (proptau[row, j] + edgeOverflowWeight*amtToFill > fillop):
                            excess = fillop - proptau[row,j]
                            proptau[row, j] = fillop
                            proptau[outerRow,leftCol] -= excess
                        
                        
                        if ((proptau[outerRow,rightCol] - (edgeOverflowWeight*amtToFill)) >= 0.) & (proptau[row, j] + edgeOverflowWeight*amtToFill <= fillop) :
                            proptau[row, j] += edgeOverflowWeight*amtToFill
                            proptau[outerRow,rightCol] -= (edgeOverflowWeight*amtToFill)    
                        elif (proptau[outerRow,rightCol] - (edgeOverflowWeight*amtToFill) < 0.):
                            proptau[row, j] += proptau[outerRow,rightCol]
                            proptau[outerRow,rightCol] = 0.
                        elif (proptau[row, j] + edgeOverflowWeight*amtToFill > fillop):
                            excess = fillop - proptau[row,j]
                            proptau[row, j] = fillop
                            proptau[outerRow,rightCol] -= excess

                    for col in extra_spillin_j:
                        proptau[outerRow, col] = 0.
                        
                    #account for prior in deciding whether to accept
                    propPrior = (1.-b**2)**0.25 * w**2 # (1-b^2)^(1/4) * p^2, from Kipping & Sandford 2016
                    oldPrior = (1.-outer_b**2)**0.25 * (w**2 * sameDuration_forOpacity) #use area of spill-in pixel blocks to calculate ratio-of-radii proxy
                    
                    #print "newtauPrior is {0}".format(oldPrior)
                    #print "proptauPrior is {0}".format(propPrior)
                    
                    proptauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(proptau,(N*M,1)))
                    proptauLC = proptauLC[:,0]
                    proptauCost = RMS(obsLC, obsLCerr, proptauLC)
                    
                    #print "newtauCost is {0}".format(newtauCost)
                    #print "proptauCost is {0}".format(proptauCost)
                    
                    deltaRMS = np.exp(-0.5*(proptauCost**2 - newtauCost**2))
                    postRatio = deltaRMS * (propPrior/oldPrior)
                    
                    #print "deltaRMS is {0}".format(deltaRMS)
                    #print "postRatio is {0}".format(postRatio)
                    
                    testProb = np.random.uniform(0.,1.)
                    if testProb < postRatio:
                        #print "south better"
                        newtau = proptau
                        newtauCost = proptauCost
                        proptau = copy.copy(newtau)
                    else:
                        proptau = copy.copy(newtau)
            
        #do not account for prior in deciding whether to accept
        """proptauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(proptau,(N*M,1)))
        proptauLC = proptauLC[:,0]
        proptauCost = RMS(obsLC, obsLCerr, proptauLC)
        
        newtau = copy.copy(proptau)
        newtauCost = proptauCost
        proptau = copy.copy(newtau)"""
        
        #get rid of extraneous "on" pixels
        """onMask = np.ravel((newtau < 0.5))
        
        onIdxs = np.arange(0,len(np.ravel(newtau)))[onMask]
        
        for idx in onIdxs:
            o_i = idx // N
            o_j = idx % M
            
            proptau = copy.copy(newtau)
            proptau[o_i, o_j] = 0.
            
            proptauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(proptau,(N*M,1)))
            proptauLC = proptauLC[:,0]
            proptauCost = RMS(obsLC, obsLCerr, proptauLC)
            
            if proptauCost < newtauCost:
                print "rounding down better"
                newtau = proptau
                newtauCost = proptauCost
                proptau = copy.copy(newtau)"""
        
        #handle situation where opacities fill to 0.5 but not beyond
        """halfOpacitiesMask = np.ravel((newtau > 0.48) & (newtau < 0.55))
        
        halfOpacitiesIdxs = np.arange(0,len(np.ravel(newtau)))[halfOpacitiesMask]
        
        for idx in halfOpacitiesIdxs:
            ho_i = idx // N
            ho_j = idx % M
            
            proptau = copy.copy(newtau)
            proptau[ho_i, ho_j] = 1.
            
            proptauLC = np.atleast_2d(np.ones_like(obsLC)).T - np.dot(areas,np.reshape(proptau,(N*M,1)))
            proptauLC = proptauLC[:,0]
            proptauCost = RMS(obsLC, obsLCerr, proptauLC)
            
            if proptauCost < newtauCost:
                print "rounding up better"
                newtau = proptau
                newtauCost = proptauCost
                proptau = copy.copy(newtau)"""
                
        
    return proptau

