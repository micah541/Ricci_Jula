using Graphs
using Distances
using Winston
using DataFrames


t = 0.06  #geometric scale
k = 125
eta = 0.01  #step size
epsilon = 0.00001 #lowest we allow distances to become.  
component_threshold = .3   #during cluster check, we define a graph with edges between points separated by this distance. If this graph has two components of a minimu size, we stop.  
soliton_threshold = 0.001   #Program will stop if the metric stops changing much
tries = 50000

min_cluster_size = 4

show =15   #after this many iterations, it shows a plots on 2d PCA axis
diskwrite = 5000  #after this many iterations, writes distance function to dist.csv
clustercheck = 20 #after this many iterations, checks if the graph is clustered
solitoncheck = 20 #how often checks if the metric has stopped changing much



function Gamma2(L,h)
    four = L*L*(h.*h)-4*L*(h.*(L*h))+2*h.*(L*L*h)+2*(L*h).*(L*h)
    return four/4
end

    

function RicciD(L, dists2)  #this is to test if the algorithm is working because of distances and not densities
    return(dists2)
end

function Ricci2(L,dists2)  #Takes the Laplace and the distance squared and returns the Ricci matrix
    n = size(dists2)[1]
    Ricci=zeros(n,n)
    LL = L*L
    for i = 1:n-1
        for j = i:n
            diff = dists2[:,i]-dists2[:,j]
            Ldiff = L*diff
            rij =  LL*(diff.*diff)-4*L*(diff.*(Ldiff))+2*diff.*(L*Ldiff)+2*(Ldiff).*(Ldiff)
            Ricci[i,j]=rij[i]
            Ricci[j,i]=rij[j] 
        end
    end 
    return (Ricci+transpose(Ricci))/8
end

    


function components(dists, threshold)   #certainly there should be a more elegant way to do this than adding the edges 1 at a time?
    n=size(dists)[1]
    
    g = simple_graph(n, is_directed=false)
    edges = [d<threshold for d in dists]
    
    edges =reshape(edges, n,n)
    
    for i in 1:n
        for j in i:n
            if(edges[i,j]) 
                add_edge!(g, i, j)
            end
        end 
    end
    cc = connected_components(g)
    return(cc)
end


function get_objects(dists, t)  #returns kernel, density, Laplacian, f
    kernel= exp(-dists.*dists/(2*t))
    density = sum(kernel,2)
    L = kernel./density-eye(size(dists)[1])
    f = -log(density)
    return kernel, density, L/t, f
end



w = ones(2*k)
points = randn(2,k)
points2 = randn(2,k)+repeat([3,0], outer=[1,k])
points = cat(2,points, points2)


#=
df = readtable("c4.csv")
print(df)
points = convert(Array,df)
points = transpose(points)
=#

display(scatter(points[1,:], points[2,:]))

dists = pairwise(Euclidean(),points, points)
print(dists)
odists = copy(dists)

kernel, dens, L, f = get_objects(dists, t)
count = 2
df1 = DataFrame(dists)
writetable("initialdistance.csv", df1)
clustered=false
n = size(dists)[1]
colors = ones(n)
soliton_check_dists = dists


while(count<tries)
    dists2 = dists.^2
    dists2 = k^2*dists2 / sum(dists2)
    print("computing Ricci...\n")
    @time Ric=RicciD(L, dists2)
    print("\n next modify and do floyd_warschall...\n")
    dists2 = dists2 - eta*kernel.*Ric #this is localized 
    dists2 = max(dists2, epsilon)  #keeping it real
    @time dists = floyd_warshall(sqrt(dists2))
    
    print("\n next get new Laplacian, density, etc..\n")
    kernel, dens, L, f = get_objects(dists, t)
    if(count%show==1)
        print(dists[1:6,1:6],'\n')
        print("and Ricci", '\n')
        print(Ric[1:4,1:4],'\n')
	eigv = eigvecs(L)
        pca1 = eigv[3,:]
        pca2 = eigv[2,:]
        try 
        display(scatter(pca1,pca2))
        catch print("scatter failed")
        end
    end
    if(count%(diskwrite)==1)  
        df1 = DataFrame(dists)
        df2 = DataFrame(Ric)
        writetable("dist.csv", df1)
        writetable("Ric.csv",df2)
 	
	
    end
    if(count%clustercheck==1)
        comps = components(dists, component_threshold)  
        print("\n\nthere are ", size(comps)[1], " components\n")
        print(comps)
 	if size(comps)[1]>1
            print("\nclustered!\n")
            clustered = true 
            nontrivial_components = 0
            for l in comps
                if(size(l)[1]>min_cluster_size)
                    nontrivial_components+=1 
                 end 
            end 
            if (nontrivial_components==1)
                clustered = false
                print("\n not enough components")
                print("\n there are ", nontrivial_components, "nontrivial components")
               
            end 

            for i in 1:n
                if (i in comps[1])
                    colors[i]=0
                end
            end  

        end
    end
    if(count%solitoncheck==1)
        change = soliton_check_dists -dists
    
        if (maximum(abs(change))<soliton_threshold )
            print("\nSoliton!\n")
            clustered = true
        end
    soliton_check_dists = dists
    end
       
 
    count = count +1 
    if(clustered) 
        break
    end 
       
end
print("Finished\n\n\n")
display(scatter(points[1,:], points[2,:], 0.3, colors))
sleep(10)
savefig("picture.png")

quit()

    





